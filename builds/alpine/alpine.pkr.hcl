variable "mirror" {
  default = "https://mirrors.sjtug.sjtu.edu.cn/alpine"
}
variable "version" {
  default = "3.13.2"
}
variable "flavor" {
  default = "virt"
}
variable "size" {
  default = "40G"
}
variable "format" {
  default     = "qcow2"
  description = "qcow2, raw"
}
variable "arch" {
  default     = "x86_64"
  description = "arch of vm"
}
variable "accel" {
  default     = "tcg"
  description = "hvf for macOS, kvm for Linux"
}
variable "boot_wait" {
  default     = "10s"
  description = "if no accel, should set at least 30s"
}
variable "dist" {
  default = "images"
}
variable "qemu_binary" {
  default = "qemu-system-x86_64"
}
variable "qemu_machine_type" {
  default = "pc"
}

variable "checksums" {
  description = "checksums of iso"
}

locals {
  # 3.12.0 -> 3.12
  ver = regex_replace(var.version, "[.][0-9]+$", "")
}

source "qemu" "alpine" {
  iso_url      = "${var.mirror}/v${local.ver}/releases/${var.arch}/alpine-${var.flavor}-${var.version}-${var.arch}.iso"
  iso_checksum = var.checksums["alpine-${var.flavor}-${var.version}-${var.arch}.iso"]

  // display = "cocoa"
  headless     = true
  accelerator  = var.accel
  qemu_binary  = var.qemu_binary
  machine_type = var.qemu_machine_type
  net_device  =  "virtio-net"

  ssh_username = "root"
  ssh_password = "root"
  ssh_timeout  = "2m"

  boot_key_interval = "10ms"
  boot_wait         = var.boot_wait
  boot_command = [
    "root<enter>",
    "setup-interfaces -a<enter>",
    "service networking restart<enter>",
    "echo root:root | chpasswd<enter><wait5>",
    "setup-sshd -c openssh<enter>",
    "echo PermitRootLogin yes >> /etc/ssh/sshd_config<enter>",
    "service sshd restart<enter>",
  ]

  disk_size = var.size
  format    = var.format

  output_directory = var.dist
}

build {
  source "qemu.alpine" {}

  provisioner "shell" {

    inline = [
      <<-EOF
echo Building $${ALPINE_VER} using $${ALPINE_MIRROR}
echo $${ALPINE_MIRROR}/v$${ALPINE_VER}/main > /etc/apk/repositories
echo $${ALPINE_MIRROR}/v$${ALPINE_VER}/community >> /etc/apk/repositories
rc-update add networking
ERASE_DISKS=/dev/vda setup-disk -m sys -s 0 -k $${ALPINE_FLAVOR} /dev/vda
EOF
    ]
    environment_vars = [
      "ALPINE_MIRROR=${var.mirror}",
      "ALPINE_FLAVOR=${var.flavor}",
      "ALPINE_VER=${local.ver}",
    ]
  }
}