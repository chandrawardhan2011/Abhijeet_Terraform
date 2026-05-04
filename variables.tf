variable "win10_count" { 
          type = number
          default=0 
       }
variable "linux_count" { 
          type = number
          default=0 
       }

variable "win10_template" {
          type=string
          default="win10-template" 
       }

variable "linux_template" {
          type=string
          default="ubuntu-template" 
       }

# SERVER TEMPLATE
variable "ubuntu_server_template" {
          type=string
          default="ubuntu-server-template" 

       }
