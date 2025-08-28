use clap::Parser;
use torrust_deploy::cli::{Cli, Commands};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Provision(cmd) => cmd.execute().await?,
    }

    Ok(())
}
