use serde_json::Value;
use std::path::Path;
use tokio::process::Command;
use tracing::{debug, info};

use crate::error::{Result, TorrustDeployError};

pub struct OpenTofu {
    working_dir: std::path::PathBuf,
}

impl OpenTofu {
    /// Create a new OpenTofu instance for the given working directory
    pub fn new(working_dir: impl AsRef<Path>) -> Self {
        Self {
            working_dir: working_dir.as_ref().to_path_buf(),
        }
    }

    /// Initialize OpenTofu in the working directory
    pub async fn init(&self) -> Result<()> {
        info!(
            "Initializing OpenTofu in directory: {}",
            self.working_dir.display()
        );

        let output = Command::new("tofu")
            .args(["init"])
            .current_dir(&self.working_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::OpenTofu(format!(
                "tofu init failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("OpenTofu init output: {}", stdout);
        info!("✅ OpenTofu initialized successfully");

        Ok(())
    }

    /// Apply OpenTofu configuration
    pub async fn apply(&self) -> Result<()> {
        info!("Applying OpenTofu configuration...");

        let output = Command::new("tofu")
            .args(["apply", "-auto-approve"])
            .current_dir(&self.working_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::OpenTofu(format!(
                "tofu apply failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("OpenTofu apply output: {}", stdout);
        info!("✅ OpenTofu configuration applied successfully");

        Ok(())
    }

    /// Get the VM IP address from OpenTofu outputs
    pub async fn get_vm_ip(&self) -> Result<String> {
        info!("Extracting VM IP from OpenTofu outputs...");

        let output = Command::new("tofu")
            .args(["output", "-json"])
            .current_dir(&self.working_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::OpenTofu(format!(
                "tofu output failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("OpenTofu output JSON: {}", stdout);

        let outputs: Value = serde_json::from_str(&stdout)?;

        let vm_ip = outputs
            .get("vm_ip")
            .and_then(|v| v.get("value"))
            .and_then(|v| v.as_str())
            .ok_or_else(|| {
                TorrustDeployError::OpenTofu(
                    "vm_ip output not found in OpenTofu outputs".to_string(),
                )
            })?;

        info!("✅ VM IP extracted: {}", vm_ip);
        Ok(vm_ip.to_string())
    }

    /// Destroy OpenTofu infrastructure (for testing/cleanup)
    pub async fn destroy(&self) -> Result<()> {
        info!("Destroying OpenTofu infrastructure...");

        let output = Command::new("tofu")
            .args(["destroy", "-auto-approve"])
            .current_dir(&self.working_dir)
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(TorrustDeployError::OpenTofu(format!(
                "tofu destroy failed: {stderr}"
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("OpenTofu destroy output: {}", stdout);
        info!("✅ OpenTofu infrastructure destroyed successfully");

        Ok(())
    }
}
