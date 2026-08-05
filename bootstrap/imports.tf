###############################################################################
# Adoption of the running container.
#
# Leave this in place. It is what makes losing terraform.tfstate here a
# non-event: a fresh `terraform plan` re-reads the live container instead of
# proposing to build a new one.
###############################################################################

import {
  to = proxmox_virtual_environment_container.minio
  id = "jd-proxmox-02/106"
}
