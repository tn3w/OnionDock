FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -m -u 1000 app && chown -R app:app /app
USER app

ENV PORT=80
EXPOSE 80

CMD ["gunicorn", "-b", "0.0.0.0:80", "-w", "2", "app:app"]
