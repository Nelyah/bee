mod api;
mod dto;
mod parse;
mod printer;

/// Entry point for the beed REST API service.
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let addr = std::env::var("BEE_API_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".to_string());
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    log::info!("beed listening on {}", addr);

    let app = api::router(api::AppState::new());
    axum::serve(listener, app).await?;
    Ok(())
}
