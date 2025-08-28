use thiserror::Error;

#[derive(Error, Debug)]
pub enum TorrustDeployError {
    #[error("OpenTofu execution failed: {0}")]
    OpenTofu(String),

    #[error("Ansible execution failed: {0}")]
    Ansible(String),

    #[error("Template processing failed: {0}")]
    Template(String),

    #[error("Command execution failed: {command}, exit code: {exit_code}, stderr: {stderr}")]
    CommandExecution {
        command: String,
        exit_code: i32,
        stderr: String,
    },

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON parsing error: {0}")]
    Json(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, TorrustDeployError>;
