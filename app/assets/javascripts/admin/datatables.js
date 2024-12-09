$(document).on('turbolinks:load', function () {
  const tableSelectors = '#purpose-travel-patterns-table, #funding-sources-table, #booking-profiles-table, #DataTables_Table_0';

  $(tableSelectors).each(function () {
    if ($.fn.DataTable.isDataTable(this)) {
      $(this).DataTable().destroy();
      $(this).empty();
    }
  });

  $(tableSelectors).each(function () {
    $(this).DataTable({
      "columnDefs": [{
        "targets": 2,
        "orderable": false
      }]
    });
  });
});

document.addEventListener('turbolinks:before-cache', function () {
  const tableSelectors = '#purpose-travel-patterns-table, #funding-sources-table, #booking-profiles-table, #DataTables_Table_0';

  $(tableSelectors).each(function () {
    if ($.fn.DataTable.isDataTable(this)) {
      $(this).DataTable().destroy();
      $(this).empty();
    }
  });
});
