###############################################################################
# Adoption of the running container.
#
# Leave this in place. It is what makes losing terraform.tfstate here a
# non-event: a fresh `terraform plan` re-reads the live container instead of
# proposing to build a new one.
###############################################################################

import {
  to = proxmox_virtual_environment_container.s3
  id = "jd-proxmox-02/107"
}

# LXC 106 (jd-minio-01) held the buckets until 2026-10-17. It is kept stopped
# (onboot off) on a spare address, 10.0.53.61 with a new MAC, since versitygw
# has its old ones, as a fallback for a week; then it is deleted by hand.
# Forget it here rather than destroy it, so an old local state file cannot
# plan a destroy.
removed {
  from = proxmox_virtual_environment_container.minio

  lifecycle {
    destroy = false
  }
}
