output "statements" {
  description = "Add to a role policy's Statement list."
  value = concat(
    local.profile,
    [for s in local.global : s if local.is_global],
    [for s in local.geographic : s if !local.is_global],
  )
}

output "inference_profile_arn" {
  value = local.profile_arn
}
