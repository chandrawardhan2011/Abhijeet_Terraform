# ─── CLIENT COUNTS ────────────────────────────────────────────────────────────

variable "win10_count" {
  type    = number
  default = 0
}

variable "linux_count" {
  type    = number
  default = 0
}

variable "kali_count" {
  type    = number
  default = 0
}

# ─── SERVER COUNTS ────────────────────────────────────────────────────────────

variable "wazuh_count" {
  type    = number
  default = 0
}

variable "web_count" {
  type    = number
  default = 0
}

variable "db_count" {
  type    = number
  default = 0
}

variable "ftp_count" {
  type    = number
  default = 0
}

# ─── TEMPLATES ────────────────────────────────────────────────────────────────

variable "ubuntu_server_template" {
  type    = string
  default = "ubuntu-server-template"
}

variable "win10_template" {
  type    = string
  default = "win10-template"
}

variable "linux_template" {
  type    = string
  default = "ubuntu-template"
}

variable "kali_template" {
  type    = string
  default = "kali-template"
}
