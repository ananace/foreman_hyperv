$(document).on('ContentLoad', function() { tfm.numFields.initAll(); });

function hypervGenerationChange(item) {
  var toIter = ['#host_compute_attributes_secure_boot_enabled', '#compute_attribute_vm_attrs_secure_boot_enabled'];
  gen = $(item).val();

  if (gen == 'BIOS') {
    for (var i = 0; i < toIter.length; ++i) {
      $(toIter[i]).attr('disabled', true);
    }
  } else {
    for (var i = 0; i < toIter.length; ++i) {
      $(toIter[i]).removeAttr('disabled');
    }
  }
}

function hypervDynamicMemoryChange(item) {
  var toIter = [
    '#host_compute_attributes_memory_maximum',
    '#host_compute_attributes_memory_minimum',
    '#compute_attribute_vm_attrs_memory_maximum',
    '#compute_attribute_vm_attrs_memory_minimum',
  ];

  if (item.checked) {
    for (var i = 0; i < toIter.length; ++i) {
      $(toIter[i]).removeAttr('disabled');
    }
  } else {
    for (var i = 0; i < toIter.length; ++i) {
      $(toIter[i]).attr('disabled', true);
    }
  }
}

function hypervHostChange(item) {
  console.log('Hyper-V host changed to ' + $(item).val());

  $('table.hyperv-host-info').hide();
  $('table.hyperv-host-info[data-host="'+$(item).val()+'"]').show();

  // TODO: Reload available switches
}

function hypervVLANModeChange(item) {
  var fieldset = [...document.querySelectorAll('fieldset.compute_attributes')].filter(el => el.contains(item))[0];

  $(fieldset.querySelectorAll('.hyperv_vlan_mode')).hide();
  $(fieldset.querySelectorAll('.hyperv_vlan_mode input')).attr('disabled', true);
  $(fieldset.querySelectorAll('.hyperv_vlan_mode select')).attr('disabled', true);

  var id = '.hyperv_vlan_mode.hyperv_vlan_' + $(item).val().toLowerCase();
  $(fieldset.querySelectorAll(id)).show();
  $(fieldset.querySelectorAll(id + ' input')).removeAttr('disabled');
  $(fieldset.querySelectorAll(id + ' select')).removeAttr('disabled');
}

function hypervVLANPrivateModeChange(item) {
  var fieldset = [...document.querySelectorAll('fieldset.compute_attributes')].filter(el => el.contains(item))[0];

  $(fieldset.querySelectorAll('.hyperv_vlan_private_mode')).hide();
  $(fieldset.querySelectorAll('.hyperv_vlan_private_mode input')).attr('disabled', true);

  if ($(item).val() == 'Promiscuous') {
    var id = '.hyperv_vlan_private_mode.hyperv_vlan_private_plural';
  } else {
    var id = '.hyperv_vlan_private_mode.hyperv_vlan_private_singular';
  }
  $(fieldset.querySelectorAll(id)).show();
  $(fieldset.querySelectorAll(id + ' input')).removeAttr('disabled');
}
