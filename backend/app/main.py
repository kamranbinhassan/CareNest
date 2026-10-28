from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import router
from app.core.config import get_settings
from app.db.session import check_database

settings = get_settings()
app = FastAPI(title="Medicine Adherence Monitoring API", version="2.0.0", description="Authenticated family care, medication schedule, dose event, and adherence API.")
if settings.allowed_origins:
    app.add_middleware(CORSMiddleware, allow_origins=list(settings.allowed_origins), allow_credentials=True, allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"], allow_headers=["Authorization", "Content-Type"])
app.include_router(router, prefix="/api/v1")


@app.get("/", tags=["health"])
def root():
    return {"message": "Medicine Adherence Monitoring API", "status": "ok", "version": "2.0.0"}


@app.get("/health", tags=["health"])
def health_check():
    try:
        connected = check_database()
    except Exception:
        connected = False
    if not connected:
        return JSONResponse(status_code=503, content={"status": "degraded", "database": "unavailable", "message": "Configure DATABASE_URL and apply migrations."})
    return {"status": "healthy", "database": "connected"}
