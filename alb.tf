data "aws_acm_certificate" "domain_cert" {
  domain   = "universal-domain.online"
  statuses = ["ISSUED"]
}

resource "aws_lb" "oauth_alb" {
  name                 = "oauth_alb"
  internal             = false
  load_balancer_type   = "application"
  security_groups      = [aws_security_group.oauth_alb_sg.id]
  subnets              = [aws_subnet.public_subnet, aws_subnet.public_subnet_1]
  preserve_host_header = true
}

resource "aws_lb_listener" "http_listener_redirect" {
  load_balancer_arn = aws_lb.oauth_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.oauth_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.domain_cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Bad gateway"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "keylock_listener_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keylock_tg.arn
  }

  condition {
    host_header {
      values = ["keyclock.universal-domain.online"]
    }
  }

  condition {
    source_ip {
      values = ["0.0.0.0/0"]
    }
  }
}

resource "aws_lb_listener_rule" "main_listener_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_tg.arn
  }

  condition {
    host_header {
      values = ["universal-domain.online"]
    }
  }

  condition {
    source_ip {
      values = ["0.0.0.0/0"]
    }
  }
}

resource "aws_lb_target_group" "keyclock_tg" {
  name        = "keyclock_tg"
  port        = 8443
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
  }
}


resource "aws_lb_target_group" "main_tg" {
  name        = "main_tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
  }
}

resource "aws_security_group" "oauth_alb_sg" {
  name        = "oauth_alb_sg"
  description = "Security group for alb"
  vpc_id      = aws_vpc.main_vpc.id
  tags = {
    Name = "oauth_alb_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_lb_https" {
  security_group_id = aws_security_group.oauth_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_lb_http" {
  security_group_id = aws_security_group.oauth_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outcoming_traffic_ipv4" {
  security_group_id = aws_security_group.oauth_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_route53_zone" "main_zone" {
  name         = "universal-domain.online"
  private_zone = false
}

resource "aws_route53_record" "subdomains" {
  for_each = toset(["keyclock"])
  zone_id  = data.aws_route53_zone.main_zone.id
  name     = "${each.key}.${data.aws_route53_zone.ollama_zone.name}"
  type     = "A"

  alias {
    name                   = aws_lb.oauth_alb.dns_name
    zone_id                = aws_lb.oauth_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "main_record" {
  zone_id = data.aws_route53_zone.main_zone.id
  name    = data.aws_route53_zone.main_zone.id
  type    = "A"

  alias {
    name                   = aws_lb.oauth_alb.dns_name
    zone_id                = aws_lb.oauth_alb.zone_id
    evaluate_target_health = true
  }
}
