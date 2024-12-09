$(document).on('turbolinks:load', function() {
  const tableSelectors = '#purpose-travel-patterns-table, #funding-sources-table, #booking-profiles-table, #DataTables_Table_0';

  // Destroy any existing DataTable instance
  $(tableSelectors).each(function() {
    if ($.fn.DataTable.isDataTable(this)) {
      $(this).DataTable().destroy();
      $(this).empty(); // Clear the table to prevent wrapper duplication
    }
  });

  // Re-initialize DataTable
  $(tableSelectors).DataTable({
    "columnDefs": [{
      "targets": 2,
      "orderable": false
    }]
  });

  // Destroy before Turbolinks cache
  document.addEventListener("turbolinks:before-cache", function() {
    $(tableSelectors).each(function() {
      if ($.fn.DataTable.isDataTable(this)) {
        $(this).DataTable().destroy();
        $(this).empty(); // Prevent duplicate wrapper elements
      }
    });
  });
});
