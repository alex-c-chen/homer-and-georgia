# 3.15 is still pre-release; Docker Hub has no plain 3.15-slim tag yet. Pin the
# beta that uv resolves to locally (see .python-version) so prod matches dev.
FROM python:3.15.0b1-slim

WORKDIR /app

# 3.15 is pre-release, so several deps ship no cp315 wheels and uv builds them
# from source: psycopg2-binary needs a C toolchain + libpq headers (pg_config);
# jiter and pydantic-core are Rust extensions and need cargo/rustup.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

RUN pip install uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY . .

EXPOSE 8080
CMD ["uv", "run", "--no-dev", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
