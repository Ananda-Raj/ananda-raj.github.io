output "api_url" {
  description = "Paste into the site settings (admin > Site settings > API URL)."
  value       = module.cdn.url
}

output "distribution_id" {
  value = module.cdn.distribution_id
}

output "function_name" {
  value = module.api.function_name
}
