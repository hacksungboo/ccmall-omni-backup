data "cloudflare_zone" "ccmall" {
  name = var.cloudflare_zone_name
}

resource "cloudflare_record" "ccmall_root" {
  zone_id = data.cloudflare_zone.ccmall.id
  name    = "@"
  type    = "A"
  value   = aws_instance.ccmall_web.public_ip
  proxied = false
  ttl     = 1
}

resource "time_sleep" "wait_for_dns" {
  depends_on      = [cloudflare_record.ccmall_root]
  create_duration = "60s"
}