docker build --platform linux/amd64 \
  -t us-central1-docker.pkg.dev/daas-mvp-472103/daas/bz_to_silver:0.0.13 .

docker push us-central1-docker.pkg.dev/daas-mvp-472103/daas/bz_to_silver:0.0.3
