FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0 \
    STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

RUN groupadd --gid 10001 apex \
    && useradd --uid 10001 --gid apex --create-home --home-dir /home/apex apex

WORKDIR /app
COPY apps/aida1145/requirements.txt /tmp/requirements.txt
RUN pip install --requirement /tmp/requirements.txt \
    && rm /tmp/requirements.txt

COPY --chown=apex:apex apps/aida1145/ /app/
COPY --chown=root:root deploy/app/entrypoint.py /usr/local/bin/apex-entrypoint
RUN chmod 0555 /usr/local/bin/apex-entrypoint

USER apex
EXPOSE 8501
ENTRYPOINT ["python", "/usr/local/bin/apex-entrypoint"]
