$(document).on('turbolinks:load', function() {
  $('.dataTables_wrapper table').each(function() {
    if ($.fn.DataTable.isDataTable(this)) {
      $(this).DataTable().destroy();
    }
  });

  $('.dataTables_wrapper table').DataTable({
    "columnDefs": [{
      "targets": 2,
      "orderable": false
    }]
  });

  document.addEventListener("turbolinks:before-cache", function() {
    $('.dataTables_wrapper table').each(function() {
      if ($.fn.DataTable.isDataTable(this)) {
        $(this).DataTable().destroy();
        $(this).empty(); 
      }
    });
  });
});
