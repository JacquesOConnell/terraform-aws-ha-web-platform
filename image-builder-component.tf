locals {
  nginx_configuration = <<-NGINX
  user nginx;
  worker_processes auto;
  error_log /var/log/nginx/error.log notice;
  pid /run/nginx.pid;

  events {
    worker_connections 1024;
  }

  http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    keepalive_timeout 65;
    server_tokens off;

    server {
      listen 80;
      server_name _;
      root /usr/share/nginx/html;
      index index.html;

      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;

      location = /health {
        access_log off;
        default_type text/plain;
        return 200 "healthy\n";
      }

      location / {
        try_files $uri $uri/ /index.html;
      }
    }
  }
  NGINX

  cloudwatch_agent_configuration = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }

    metrics = {
      namespace = "JNIT/HAWebPlatform"

      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
        InstanceId           = "$${aws:InstanceId}"
        InstanceType         = "$${aws:InstanceType}"
      }

      aggregation_dimensions = [
        ["AutoScalingGroupName"],
        ["InstanceId"]
      ]

      metrics_collected = {
        mem = {
          measurement = ["mem_used_percent"]
        }

        disk = {
          measurement = ["used_percent"]
          resources   = ["/"]
        }
      }
    }

    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/nginx/access.log"
              log_group_name  = "/jnit/ha-web-platform/nginx/access"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/error.log"
              log_group_name  = "/jnit/ha-web-platform/nginx/error"
              log_stream_name = "{instance_id}"
            }
          ]
        }
      }
    }
  })
}

resource "aws_imagebuilder_component" "web_server" {
  name        = "${var.project_name}-web-server"
  description = "Install and test Nginx, the JNIT website and CloudWatch Agent"
  platform    = "Linux"
  version     = "1.0.1"

  data = yamlencode({
    schemaVersion = "1.0"

    phases = [
      {
        name = "build"

        steps = [
          {
            name   = "InstallPackages"
            action = "ExecuteBash"

            inputs = {
              commands = [
                "dnf install -y nginx unzip amazon-cloudwatch-agent"
              ]
            }
          },
          {
            name   = "InstallWebsite"
            action = "ExecuteBash"

            inputs = {
              commands = [
                "aws s3 cp s3://${aws_s3_bucket.artifacts.id}/${aws_s3_object.website.key} /tmp/website.zip",
                "rm -rf /usr/share/nginx/html/*",
                "unzip -q /tmp/website.zip -d /usr/share/nginx/html",
                "chown -R nginx:nginx /usr/share/nginx/html",
                "chmod -R a+rX /usr/share/nginx/html",
                "rm -f /tmp/website.zip"
              ]
            }
          },
          {
            name   = "ConfigureNginx"
            action = "ExecuteBash"

            inputs = {
              commands = [
                "printf '%s' '${base64encode(local.nginx_configuration)}' | base64 --decode > /etc/nginx/nginx.conf",
                "systemctl enable nginx"
              ]
            }
          },
          {
            name   = "ConfigureCloudWatchAgent"
            action = "ExecuteBash"

            inputs = {
              commands = [
                "printf '%s' '${base64encode(local.cloudwatch_agent_configuration)}' | base64 --decode > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json",
                "systemctl enable amazon-cloudwatch-agent"
              ]
            }
          }
        ]
      },
      {
        name = "validate"

        steps = [
          {
            name   = "ValidateConfiguration"
            action = "ExecuteBash"

            inputs = {
              commands = [
                "nginx -t",
                "python3 -m json.tool /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null",
                "test -f /usr/share/nginx/html/index.html",
                "systemctl is-enabled nginx",
                "systemctl is-enabled amazon-cloudwatch-agent"
              ]
            }
          }
        ]
      },
      {
        name = "test"

        steps = [
          {
            name   = "TestGoldenImage"
            action = "ExecuteBash"

            inputs = {
              commands = [
                "systemctl start nginx",
                "curl --fail --silent http://localhost/health | grep healthy",
                "curl --fail --silent http://localhost/ | grep -i JNIT",
                "test -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent"
              ]
            }
          }
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-web-server-component"
  }
}