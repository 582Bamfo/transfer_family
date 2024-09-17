resource "aws_cloudwatch_log_group" "wildglobal_logs" {
    name = "wildglobal_logs"
#    name_prefix = "transfer_wildglobal_"
    retention_in_days = 1
    tags = {
    department = "wild_global"
    env = "dev"
  }
}



resource "aws_iam_role" "iam_for_transfer" {
  name_prefix         = "iam_for_transfer_"
  assume_role_policy  = data.aws_iam_policy_document.transfer_assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"]
}

resource "aws_transfer_server" "transfer" {
  endpoint_type = "PUBLIC"
  domain = "EFS"
  logging_role  = aws_iam_role.iam_for_transfer.arn
  protocols     = ["SFTP"]
  identity_provider_type = "SERVICE_MANAGED"
  # endpoint_details {
  #   subnet_ids = [data.aws_subnet.default.id]
  #   vpc_id     = data.aws_vpc.wild_vpc.id
  #   security_group_ids = [aws_security_group.allow_transfer.id]

  # }
 # sftp_authentication_methods = "PUBLIC_KEY_OR_PASSWORD"
  force_destroy = false
  pre_authentication_login_banner = "Welcome to our SFTP service. Please authenticate to continue."
  security_policy_name = "TransferSecurityPolicy-2018-11"
  structured_log_destinations = [
    "${aws_cloudwatch_log_group.wildglobal_logs.arn}:*"
  ]

  tags = {
    department = "wild_global_transfer_server"
    env = "dev"
}
}

resource "aws_security_group" "allow_transfer" {
  name        = "allow_transfer_family"
  description = "Allow  inbound traffic and all outbound traffic"
  vpc_id      = data.aws_vpc.wild_vpc.id

  tags = {
    Name = "allow_transfer_family"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_transfer.id
  cidr_ipv4         = data.aws_vpc.wild_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_transfer.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_transfer_user" "fullaccess" {
  server_id = aws_transfer_server.transfer.id
  user_name = "bamfo"
  role      = aws_iam_role.iam_for_transfer-fullaccess.arn

  home_directory_type = "PATH"
  #home_directory = "/home/bamfo"
  home_directory  = "/${aws_efs_file_system.wild_efs.id}"
  #  home_directory_mappings {
  #    entry  = "/"
  #    target = "/${aws_efs_file_system.wild_efs.id}/home/bamfo"
  #  }

  posix_profile {
    uid = 1001
    gid = 1001
  }

}

resource "aws_iam_role" "iam_for_transfer-fullaccess" {
  name = "wildglobal-transfer"
#  name_prefix         = "iam_for_transfer_"
  assume_role_policy  = data.aws_iam_policy_document.transfer_assume_role.json
  managed_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess",
  "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess",
  "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess",
  "arn:aws:iam::aws:policy/AWSTransferFullAccess"
  ]
}


resource "aws_efs_file_system" "wild_efs" {

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "wild-efs"
  }
}

# Data source for default VPC
data "aws_vpc" "wild_vpc" {
  default = true
}

# Data source for default subnet in the first availability zone
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.wild_vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  default_for_az    = true
}

# Data source for current region
data "aws_region" "current" {}

# Create EFS mount target
resource "aws_efs_mount_target" "wildmt" {
  file_system_id  = aws_efs_file_system.wild_efs.id
  subnet_id       = data.aws_subnet.default.id
  
}

# Output the EFS ID and mount target DNS name
output "efs_id" {
  value = aws_efs_file_system.wild_efs.id
}

output "mount_target_dns_name" {
  value = aws_efs_mount_target.wildmt.dns_name

}

output "server_endpoint" {
 value =  aws_transfer_server.transfer.endpoint
}

resource "aws_efs_access_point" "test" {
  file_system_id = aws_efs_file_system.wild_efs.id
 posix_user {
    uid = 1001
    gid = 1001
  } 
 root_directory {
  path = "/"
   creation_info {
     owner_gid = 1001
    owner_uid = 1001
    permissions  = "777"
   }
 }

}

