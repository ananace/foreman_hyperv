function hypervGenerationChange(item) {
    var toIter = ['#host_compute_attributes_secure_boot_enabled', '#compute_attribute_vm_attrs_secure_boot_enabled'];
    gen = $(item).val();

    if (gen == 1) {
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
