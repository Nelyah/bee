mod api;
mod config;
mod dto;
mod error_type;
mod external_links;
mod parse;
mod printer;

use bee_core::UserFacingError;

/// Entry point for the bee-api REST API service.
#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        log::error!("bee-api error: {}", err.developer_message());
        std::process::exit(1);
    }
}

async fn run() -> error_type::ApiResult<()> {
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

    let listener = tokio::net::TcpListener::bind(&config.bind_addr)
        .await
        .map_err(|err| error_type::ApiError::internal(format!("Failed to bind: {err}")))?;

    log::info!("beed listening on {}", config.bind_addr);

    let app = api::router(api::AppState::from_config(config));
    axum::serve(listener, app)
        .await
        .map_err(|err| error_type::ApiError::internal(format!("Server error: {err}")))?;
    Ok(())
}
