$(document).on('turbolinks:load', function() {
  const tableSelectors = [
    '#purpose-travel-patterns-table',
    '#funding-sources-table',
    '#booking-profiles-table',
    '#DataTables_Table_0' 
  ];

  tableSelectors.forEach(selector => {
    if ($.fn.DataTable.isDataTable(selector)) {
      $(selector).DataTable().destroy();
    }

    $(selector).DataTable({
      "columnDefs": [{
        "targets": 2,
        "orderable": false
      }]
    });
  });

  document.addEventListener("turbolinks:before-cache", function() {
    tableSelectors.forEach(selector => {
      if ($.fn.DataTable.isDataTable(selector)) {
        $(selector).DataTable().destroy();
      }
    });
  });
});
