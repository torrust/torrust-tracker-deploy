use clap::Parser;
use std::path::Path;
use tracing::info;

use crate::error::Result;
use crate::providers::{ansible::Ansible, opentofu::OpenTofu};
use crate::templates::TemplateManager;

#[derive(Parser)]
pub struct ProvisionCommand {
    /// Working directory for build artifacts
    #[arg(long, default_value = "build")]
    pub build_dir: String,
}

impl ProvisionCommand {
    pub async fn execute(&self) -> Result<()> {
        info!("🚀 Starting Torrust Tracker VM provisioning...");

        let build_dir = Path::new(&self.build_dir);
        let tofu_dir = build_dir.join("tofu");
        let ansible_dir = build_dir.join("ansible");

        // Initialize providers
        let opentofu = OpenTofu::new(&tofu_dir);
        let ansible = Ansible::new();
        let template_manager = TemplateManager::new();

        // Step 1: Copy OpenTofu templates
        info!("📁 Copying OpenTofu templates...");
        template_manager.copy_tofu_templates(&tofu_dir).await?;

        // Step 2: Initialize OpenTofu
        info!("🔧 Initializing OpenTofu...");
        opentofu.init().await?;

        // Step 3: Apply OpenTofu configuration
        info!("☁️  Applying OpenTofu configuration (this may take several minutes)...");
        opentofu.apply().await?;

        // Step 4: Get VM IP
        info!("🔍 Extracting VM IP address from OpenTofu output...");
        let vm_ip = opentofu.get_vm_ip().await?;
        info!("✅ VM provisioned successfully with IP: {}", vm_ip);

        // Step 5: Setup Ansible
        info!("📋 Setting up Ansible configuration...");
        ansible
            .copy_templates_and_generate_inventory(&vm_ip, &ansible_dir)
            .await?;

        // Step 6: Wait for cloud-init
        info!("⏳ Waiting for cloud-init completion using Ansible...");
        ansible.wait_for_cloud_init(&ansible_dir).await?;

        // Step 7: Run verification
        info!("🔍 Running Ansible post-provision verification...");
        ansible.run_verification(&ansible_dir).await?;

        // Step 8: Restart VM
        info!("🔄 Restarting VM using Ansible...");
        ansible.restart_vm(&ansible_dir).await?;

        info!("🎉 Provisioning completed successfully!");
        info!("📊 Summary:");
        info!("   • VM IP: {}", vm_ip);
        info!("   • SSH Access: ssh torrust@{}", vm_ip);
        info!("   • Build Directory: {}", build_dir.display());

        Ok(())
    }
}
