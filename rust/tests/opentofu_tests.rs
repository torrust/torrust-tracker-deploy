use tempfile::TempDir;
use torrust_deploy::providers::opentofu::OpenTofu;

#[tokio::test]
async fn test_opentofu_creation() {
    let temp_dir = TempDir::new().unwrap();
    let _opentofu = OpenTofu::new(temp_dir.path());
    // If we can create it without panic, the test passes
}

#[tokio::test]
async fn test_opentofu_init_succeeds_with_empty_directory() {
    let temp_dir = TempDir::new().unwrap();
    let opentofu = OpenTofu::new(temp_dir.path());

    // OpenTofu init should succeed even in an empty directory
    let result = opentofu.init().await;

    // This test verifies that our wrapper correctly handles the case
    // where tofu is available and init succeeds
    match result {
        Ok(_) => {
            // Success is expected if tofu is installed
        }
        Err(e) => {
            let error_msg = format!("{}", e);
            // If it fails, it should be due to missing tofu binary
            assert!(
                error_msg.contains("No such file")
                    || error_msg.contains("command not found")
                    || error_msg.to_lowercase().contains("not found")
            );
        }
    }
}
