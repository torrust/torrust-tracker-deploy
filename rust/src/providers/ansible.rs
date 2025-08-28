use std::path::Path;
use tokio::process::Command;
use tracing::{debug, info};

use crate::error::{Result, TorrustDeployError};
use crate::templates::TemplateManager;

#[derive(Default)]
pub struct Ansible;

impl Ansible {
    /// Create a new Ansible instance
    pub fn new() -> Self {
        Self
    }

    /// Copy Ansible templates to working directory and generate inventory with VM IP
    pub async fn copy_templates_and_generate_inventory(
        &self,
        vm_ip: &str,
        ansible_dir: &Path,
    ) -> Result<()> {
        info!("Setting up Ansible configuration...");

        let template_manager = TemplateManager::new();

        // Copy Ansible templates
        template_manager.copy_ansible_templates(ansible_dir).await?;

        // Generate inventory with VM IP
        template_manager
            .generate_inventory(vm_ip, ansible_dir)
            .await?;

        info!("✅ Ansible setup completed successfully");
        Ok(())
    }

    /// Wait for cloud-init completion using Ansible playbook
    pub async fn wait_for_cloud_init(&self, ansible_dir: &Path) -> Result<()> {
        info!("⏳ Waiting for cloud-init completion using Ansible...");

        let output = Command::new("ansible-playbook")
            .args(["-i", "inventory.ini", "wait-for-cloud-init.yml"])
            .current_dir(ansible_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::Ansible(format!(
                "ansible-playbook wait-for-cloud-init failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("Ansible wait-for-cloud-init output: {}", stdout);
        info!("✅ Cloud-init completion verified via Ansible!");

        Ok(())
    }

    /// Run the post-provision verification playbook
    pub async fn run_verification(&self, ansible_dir: &Path) -> Result<()> {
        info!("🔍 Running Ansible post-provision verification...");

        let output = Command::new("ansible-playbook")
            .args(["-i", "inventory.ini", "post-provision-verification.yml"])
            .current_dir(ansible_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::Ansible(format!(
                "ansible-playbook post-provision-verification failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("Ansible verification output: {}", stdout);
        info!("✅ Ansible verification completed successfully!");

        Ok(())
    }

    /// Restart the VM after post-provision verification
    pub async fn restart_vm(&self, ansible_dir: &Path) -> Result<()> {
        info!("🔄 Restarting VM using Ansible...");

        let output = Command::new("ansible-playbook")
            .args(["-i", "inventory.ini", "restart-vm.yml"])
            .current_dir(ansible_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::Ansible(format!(
                "ansible-playbook restart-vm failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("Ansible restart-vm output: {}", stdout);
        info!("✅ VM restart completed successfully!");

        Ok(())
    }
}
