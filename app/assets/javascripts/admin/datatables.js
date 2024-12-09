$(document).on('turbolinks:load', function () {
  const tableSelectors = [
    '#purpose-travel-patterns-table',
    '#funding-sources-table',
    '#booking-profiles-table',
    '#DataTables_Table_0',
  ];

  tableSelectors.forEach((selector) => {
    if ($.fn.DataTable.isDataTable(selector)) {
      $(selector).dataTable().fnDestroy();
    }

    $(selector).dataTable({
      columnDefs: [
        {
          targets: 2,
          orderable: false,
        },
      ],
      lengthMenu: [10, 25, 50],
      autoWidth: false,
      destroy: true,
    });
  });

  document.addEventListener('turbolinks:before-cache', function () {
    tableSelectors.forEach((selector) => {
      if ($.fn.DataTable.isDataTable(selector)) {
        $(selector).dataTable().fnDestroy();
      }
    });
  });
});
