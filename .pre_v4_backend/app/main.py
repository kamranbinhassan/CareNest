from fastapi import FastAPI

app = FastAPI(
    title="Medicine Adherence Monitoring API",
    version="1.0.0",
)


@app.get("/")
def root():
    return {
        "message": "Medicine Adherence Monitoring API is running",
        "status": "ok",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
    }
