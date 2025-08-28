use std::path::Path;
use tokio::fs;
use tracing::{debug, info};

use crate::error::{Result, TorrustDeployError};

#[derive(Default)]
pub struct TemplateManager;

impl TemplateManager {
    /// Create a new TemplateManager instance
    pub fn new() -> Self {
        Self
    }

    /// Copy OpenTofu templates to the working directory
    pub async fn copy_tofu_templates(&self, dest_dir: &Path) -> Result<()> {
        info!("Copying OpenTofu templates to {}", dest_dir.display());

        // Create destination directory
        fs::create_dir_all(dest_dir).await?;

        let templates_dir = Path::new("templates");

        // Copy main.tf
        let main_tf_src = templates_dir.join("main.tf");
        let main_tf_dest = dest_dir.join("main.tf");
        self.copy_file(&main_tf_src, &main_tf_dest).await?;

        // Copy cloud-init.yml
        let cloud_init_src = templates_dir.join("tofu").join("cloud-init.yml");
        let cloud_init_dest = dest_dir.join("cloud-init.yml");
        self.copy_file(&cloud_init_src, &cloud_init_dest).await?;

        info!("✅ OpenTofu templates copied successfully");
        Ok(())
    }

    /// Copy Ansible templates to the working directory
    pub async fn copy_ansible_templates(&self, dest_dir: &Path) -> Result<()> {
        info!("Copying Ansible templates to {}", dest_dir.display());

        // Create destination directory
        fs::create_dir_all(dest_dir).await?;

        let templates_dir = Path::new("templates").join("ansible");

        // List of files to copy
        let files_to_copy = [
            "ansible.cfg",
            "wait-for-cloud-init.yml",
            "post-provision-verification.yml",
            "restart-vm.yml",
        ];

        for file in &files_to_copy {
            let src = templates_dir.join(file);
            let dest = dest_dir.join(file);
            self.copy_file(&src, &dest).await?;
        }

        info!("✅ Ansible templates copied successfully");
        Ok(())
    }

    /// Generate Ansible inventory file with VM IP
    pub async fn generate_inventory(&self, vm_ip: &str, ansible_dir: &Path) -> Result<()> {
        info!("Generating Ansible inventory with VM IP: {}", vm_ip);

        let template_path = Path::new("templates")
            .join("ansible")
            .join("inventory.ini.template");
        let inventory_path = ansible_dir.join("inventory.ini");

        // Read template
        let template_content = fs::read_to_string(&template_path).await.map_err(|e| {
            TorrustDeployError::Template(format!(
                "Failed to read inventory template {}: {}",
                template_path.display(),
                e
            ))
        })?;

        // Replace placeholder with actual VM IP
        let inventory_content = template_content.replace("{{VM_IP}}", vm_ip);

        // Write inventory file
        fs::write(&inventory_path, inventory_content)
            .await
            .map_err(|e| {
                TorrustDeployError::Template(format!(
                    "Failed to write inventory file {}: {}",
                    inventory_path.display(),
                    e
                ))
            })?;

        info!(
            "✅ Generated inventory: {} (VM IP: {})",
            inventory_path.display(),
            vm_ip
        );
        Ok(())
    }

    /// Copy a single file with error handling
    pub async fn copy_file(&self, src: &Path, dest: &Path) -> Result<()> {
        debug!("Copying file: {} -> {}", src.display(), dest.display());

        // Check if source file exists
        if !src.exists() {
            return Err(TorrustDeployError::Template(format!(
                "Template file not found: {}",
                src.display()
            )));
        }

        // Create destination directory if it doesn't exist
        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent).await?;
        }

        // Copy the file
        fs::copy(src, dest).await.map_err(|e| {
            TorrustDeployError::Template(format!(
                "Failed to copy {} to {}: {}",
                src.display(),
                dest.display(),
                e
            ))
        })?;

        debug!("✅ Copied: {} -> {}", src.display(), dest.display());
        Ok(())
    }
}
