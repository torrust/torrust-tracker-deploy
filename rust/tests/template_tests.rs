use std::path::Path;
use tempfile::TempDir;
use torrust_deploy::templates::TemplateManager;

#[tokio::test]
async fn test_template_manager_creation() {
    let _manager = TemplateManager::new();
    // If we can create it without panic, the test passes
}

#[tokio::test]
async fn test_copy_file_with_missing_source() {
    let manager = TemplateManager::new();
    let temp_dir = TempDir::new().unwrap();

    let non_existent_src = Path::new("does_not_exist.txt");
    let dest = temp_dir.path().join("dest.txt");

    // This should fail because source doesn't exist
    let result = manager.copy_file(&non_existent_src, &dest).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_generate_inventory_template_substitution() {
    let manager = TemplateManager::new();
    let temp_dir = TempDir::new().unwrap();

    // Create a mock template file
    let template_content = "[torrust_vm]\n{{VM_IP}} ansible_user=torrust\n";
    let template_path = temp_dir.path().join("inventory.ini.template");
    tokio::fs::write(&template_path, template_content)
        .await
        .unwrap();

    // Create templates/ansible directory structure in temp dir
    let templates_ansible_dir = temp_dir.path().join("templates").join("ansible");
    tokio::fs::create_dir_all(&templates_ansible_dir)
        .await
        .unwrap();
    tokio::fs::write(
        templates_ansible_dir.join("inventory.ini.template"),
        template_content,
    )
    .await
    .unwrap();

    let ansible_dir = temp_dir.path().join("ansible");
    tokio::fs::create_dir_all(&ansible_dir).await.unwrap();

    // Change to temp directory to make relative paths work
    let original_dir = std::env::current_dir().unwrap();
    std::env::set_current_dir(temp_dir.path()).unwrap();

    // Test IP substitution
    let vm_ip = "192.168.1.100";
    let result = manager.generate_inventory(vm_ip, &ansible_dir).await;

    // Restore original directory
    std::env::set_current_dir(original_dir).unwrap();

    assert!(result.is_ok());

    // Check that the file was created and IP was substituted
    let inventory_path = ansible_dir.join("inventory.ini");
    assert!(inventory_path.exists());

    let content = tokio::fs::read_to_string(&inventory_path).await.unwrap();
    assert!(content.contains("192.168.1.100"));
    assert!(!content.contains("{{VM_IP}}"));
}
