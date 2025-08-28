use torrust_deploy::providers::ansible::Ansible;

#[tokio::test]
async fn test_ansible_creation() {
    let _ansible = Ansible::new();
    // If we can create it without panic, the test passes
}

#[tokio::test]
async fn test_ansible_wait_for_cloud_init_without_ansible_binary() {
    let ansible = Ansible::new();
    let temp_dir = tempfile::TempDir::new().unwrap();

    // This should fail because ansible-playbook binary is not available in test environment
    let result = ansible.wait_for_cloud_init(temp_dir.path()).await;
    assert!(result.is_err());

    // Verify it's the right kind of error
    if let Err(e) = result {
        let error_msg = format!("{}", e);
        // Should fail due to missing ansible-playbook binary
        assert!(error_msg.contains("Ansible") || error_msg.contains("ansible"));
    }
}
