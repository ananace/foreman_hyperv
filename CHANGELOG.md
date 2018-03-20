## v0.0.4 **Unreleased**

- Allow setting a VM-wide VLAN value
- Default to using the first available cluster if one exists
  - This allows the use of clustered machines, as long as all machines are set up with identical switch configurations
- Support the creation of legacy NICs for BIOS
  - Requires fog-hyperv 0.0.8 / d4bf0fcdef691573c25744c3f3930961d5f767d6

## v0.0.3 2018-01-15

- Fix association of VMs by MAC address (case issue)
- Fix over-eager secure boot setting access on unpersisted VMs
- Fix over-eager cluster iteration, ensure the hypervisor supports clusters first (Requires fog-hyperv v0.0.6)

## v0.0.2 2017-08-30

- Add Dynamic memory settings
- Add JS for disabling unavailable settings to improve UX
- Fix secure boot setting to actually apply
- Skip several unnecessary Hyper-V calls to improve performance
- Improve VM properties view to look a little better and house another few nuggets of information

## v0.0.1 2017-08-28

- Initial release
