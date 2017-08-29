function hypervGenerationChange(item) {
    gen = $(item).val();

    if (gen == 1) {
        $('#host_compute_attributes_secure_boot_enabled').attr('disabled', true);
    } else {
        $('#host_compute_attributes_secure_boot_enabled').removeAttr('disabled');
    }
}

function hypervDynamicMemoryChange(item) {
    if (item.checked) {
        $('#host_compute_attributes_memory_maximum').removeAttr('disabled');
        $('#host_compute_attributes_memory_minimum').removeAttr('disabled');
    } else {
        $('#host_compute_attributes_memory_maximum').attr('disabled', true);
        $('#host_compute_attributes_memory_minimum').attr('disabled', true);
    }
}
