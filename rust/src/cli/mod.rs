pub mod commands;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(
    name = "torrust-deploy",
    author = "Torrust Team",
    version = "0.1.0",
    about = "Deploy Torrust Tracker to cloud providers using OpenTofu/Terraform and cloud-init",
    long_about = "A modern Rust console application for deploying Torrust Tracker to cloud providers using OpenTofu/Terraform and cloud-init for VM configuration."
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    /// Enable verbose output
    #[arg(long, global = true)]
    pub verbose: bool,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Provision Torrust Tracker VM using OpenTofu
    Provision(commands::provision::ProvisionCommand),
}
