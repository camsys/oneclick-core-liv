$(document).on('turbolinks:load', function() {
  const tableSelectors = [
    '#DataTables_Table_4',
    '#purpose-travel-patterns-table',
    '#funding-sources-table',
    '#booking-profiles-table'
  ];

  tableSelectors.forEach(function(selector) {
    if ($.fn.DataTable.isDataTable(selector)) {
      $(selector).DataTable().destroy();
      $(selector).empty(); 
    }

    $(selector).DataTable({
      "columnDefs": [{
        "targets": 2,
        "orderable": false
      }]
    });
  });

  document.addEventListener("turbolinks:before-cache", function() {
    tableSelectors.forEach(function(selector) {
      if ($.fn.DataTable.isDataTable(selector)) {
        $(selector).DataTable().destroy();
        $(selector).empty();
      }
    });
  });
});
