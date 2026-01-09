mod api;
mod background;
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

    // Environment variables override config file settings
    if let Ok(addr) = std::env::var("BEE_API_ADDR") {
        config.bind_addr = addr;
    }
    if let Ok(socket) = std::env::var("BEE_API_SOCKET") {
        config.socket_path = Some(std::path::PathBuf::from(socket));
    }

    // Spawn background external links sync job
    background::spawn_external_links_sync_job(
        bee_core::config::get_config().external_links.clone(),
        config.external_links.sync.clone(),
    );

    // Validate no static/user report name collisions before serving
    api::AppState::validate_report_name_collisions().await;

    let app = api::router(api::AppState::from_config(config.clone()));

    // Use Unix socket if configured, otherwise TCP
    if let Some(socket_path) = config.socket_path {
        serve_unix_socket(app, &socket_path).await?;
    } else {
        // TCP mode (default)
        let listener = tokio::net::TcpListener::bind(&config.bind_addr)
            .await
            .map_err(|err| error_type::ApiError::internal(format!("Failed to bind: {err}")))?;

        log::info!("beed listening on {}", config.bind_addr);

        axum::serve(listener, app)
            .await
            .map_err(|err| error_type::ApiError::internal(format!("Server error: {err}")))?;
    }

    Ok(())
}

/// Serve the axum app on a Unix domain socket using hyper-util.
/// This is required because axum 0.7's `serve` only accepts TcpListener.
async fn serve_unix_socket(
    app: axum::Router,
    socket_path: &std::path::Path,
) -> error_type::ApiResult<()> {
    use hyper::server::conn::http1;
    use hyper_util::rt::TokioIo;
    use tower::Service;

    // Remove stale socket file if it exists
    let _ = std::fs::remove_file(socket_path);

    let listener = tokio::net::UnixListener::bind(socket_path).map_err(|err| {
        error_type::ApiError::internal(format!(
            "Failed to bind Unix socket {}: {err}",
            socket_path.display()
        ))
    })?;

    log::info!("beed listening on Unix socket: {}", socket_path.display());

    // Accept connections in a loop
    loop {
        let (stream, _addr) = listener.accept().await.map_err(|err| {
            error_type::ApiError::internal(format!("Failed to accept connection: {err}"))
        })?;

        let tower_service = app.clone();

        // Spawn a task to handle the connection
        tokio::spawn(async move {
            let socket = TokioIo::new(stream);

            let hyper_service = hyper::service::service_fn(
                move |request: hyper::Request<hyper::body::Incoming>| {
                    tower_service.clone().call(request)
                },
            );

            if let Err(err) = http1::Builder::new()
                .serve_connection(socket, hyper_service)
                .await
            {
                log::warn!("Error serving connection: {err}");
            }
        });
    }
}
