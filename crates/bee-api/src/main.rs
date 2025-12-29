mod api;
mod config;
mod dto;
mod parse;
mod printer;

/// Entry point for the bee-api REST API service.
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut logger =
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"));
    logger
        .filter_module("sqlx", log::LevelFilter::Warn)
        .filter_module("sea_orm", log::LevelFilter::Warn)
        .filter_module("sea_orm::query", log::LevelFilter::Warn)
        .filter_module("sea_orm::executor", log::LevelFilter::Warn)
        .init();

    let mut config = config::load_config()?;
    if let Ok(addr) = std::env::var("BEE_API_ADDR") {
        config.bind_addr = addr;
    }

    let listener = tokio::net::TcpListener::bind(&config.bind_addr).await?;

    log::info!("beed listening on {}", config.bind_addr);

    let app = api::router(api::AppState::from_config(config));
    axum::serve(listener, app).await?;
    Ok(())
}
