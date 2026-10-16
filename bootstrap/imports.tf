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

# LXC 106 (jd-minio-01) held the buckets until 2026-10-17 and was deleted by
# hand the same day, once versitygw was verified. Forget it rather than
# destroy it, so an old local state file plans nothing for it.
removed {
  from = proxmox_virtual_environment_container.minio

  lifecycle {
    destroy = false
  }
}
