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
  var parent = [...document.querySelectorAll('fieldset.compute_attributes')].filter(el => el.contains(item))[0];
  if (parent == undefined) {
    parent = [...document.querySelectorAll('div.fields')].filter(el => el.contains(item))[0];
  }

  $(parent.querySelectorAll('[data-hyperv-vlan-mode]')).hide();
  $(parent.querySelectorAll('[data-hyperv-vlan-mode] input')).attr('disabled', true);
  $(parent.querySelectorAll('[data-hyperv-vlan-mode] select')).attr('disabled', true);

  var id = '[data-hyperv-vlan-mode="' + $(item).val().toLowerCase() + '"]';
  $(parent.querySelectorAll(id)).show();
  $(parent.querySelectorAll(id + ' input')).removeAttr('disabled');
  $(parent.querySelectorAll(id + ' select')).removeAttr('disabled');
}

function hypervVLANPrivateModeChange(item) {
  var parent = [...document.querySelectorAll('fieldset.compute_attributes')].filter(el => el.contains(item))[0];
  if (parent == undefined) {
    parent = [...document.querySelectorAll('div.fields')].filter(el => el.contains(item))[0];
  }

  $(parent.querySelectorAll('[data-hyperv-vlan-private-mode]')).hide();
  $(parent.querySelectorAll('[data-hyperv-vlan-private-mode] input')).attr('disabled', true);

  if ($(item).val() == 'Promiscuous') {
    var id = '[data-hyperv-vlan-private-mode="plural"]';
  } else {
    var id = '[data-hyperv-vlan-private-mode="singular"]';
  }
  $(parent.querySelectorAll(id)).show();
  $(parent.querySelectorAll(id + ' input')).removeAttr('disabled');
}
