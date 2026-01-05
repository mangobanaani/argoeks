# Serverless & Edge

## Lambda (HTTP API)
- Write functions under `functions/<name>/` (sample: `functions/hello`).
- Package: `make package-lambda`   zips into `functions/dist/`.
- Config: add entries to `envs.<env>.functions` in `config/platform.yaml`.
- Terraform wires `modules/functions/lambda_function` per env; set `http_api.enabled` and `routes` for an HTTP endpoint.

## API Gateway Modules
- HTTP API (v2): `terraform/modules/apigw/http_api`
  - Inputs: `name`, CORS, and a list of `{ route_key, lambda_arn }` pairs.
  - Outputs: `api_endpoint`, `stage_arn` (attach WAF via WAFv2 association).
- REST API (v1): `terraform/modules/apigw/rest_api`
  - Inputs: `name`, `region`, `openapi_path`, `stage_name`, optional `wafv2_acl_arn`.
  - Outputs: `invoke_url`, `stage_arn`.

## Edge (CloudFront Functions)
- Module: `terraform/modules/edge/cloudfront_function` (us‑east‑1).
- Provide `name` and `code_path` (JavaScript), then attach to a distribution’s viewer‑request/response.
