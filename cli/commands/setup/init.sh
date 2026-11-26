pantheon_setup_init() {
  pantheon_prepare_setup_step 'Extend the LVM root volume to the full disk (when there is one) and set the timezone.'

  # The Ubuntu Server installer's LVM layout leaves the rest of the disk
  # unallocated, so this claims it. A host installed without LVM has no such
  # volume: 'lvs' fails on it, and under 'set -euo pipefail' that failure used to
  # abort the whole run at its first step, so the volume is checked up front.
  # 'lvextend' exits non-zero when there is nothing left to claim, so the free
  # extents are checked too. 'resize2fs' needs no such guard: it exits 0 when the
  # filesystem already spans the volume.
  local volume_group free_extents
  if lvs "$PANTHEON_LVM_DEVICE" >/dev/null 2>&1; then
    volume_group="$(lvs --noheadings -o vg_name "$PANTHEON_LVM_DEVICE" | tr -d '[:space:]')"
    free_extents="$(vgs --noheadings -o vg_free_count "$volume_group" | tr -d '[:space:]')"

    if [[ "$free_extents" =~ ^[0-9]+$ ]] && ((free_extents > 0)); then
      pantheon_log_info 'Extending LVM logical volume to full disk capacity...'
      lvextend -An -l +100%FREE "$PANTHEON_LVM_DEVICE"
    else
      pantheon_log_info "No unallocated extents left in ${volume_group}."
    fi

    resize2fs "$PANTHEON_LVM_DEVICE"
    pantheon_log_success 'Disk fully allocated.'
  else
    pantheon_log_info "No logical volume at ${PANTHEON_LVM_DEVICE}: skipping the storage step (pass --lvm-device for another volume)."
  fi

  if [[ -z "$PANTHEON_TIMEZONE" ]]; then
    pantheon_log_warn 'Could not read the current timezone: pass --timezone to set one.'
  elif [[ "$PANTHEON_TIMEZONE" == "$(pantheon_current_timezone)" ]]; then
    pantheon_log_success "Timezone already ${PANTHEON_TIMEZONE}."
  else
    pantheon_log_info "Setting the server timezone to ${PANTHEON_TIMEZONE}..."
    timedatectl set-timezone "$PANTHEON_TIMEZONE"
    pantheon_log_success "Timezone set to ${PANTHEON_TIMEZONE}."
  fi
}

pantheon_setup_init
