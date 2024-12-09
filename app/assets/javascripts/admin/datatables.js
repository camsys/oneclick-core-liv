$(document).on('turbolinks:load', function() {
  const tableSelectors = '#purpose-travel-patterns-table, #funding-sources-table, #booking-profiles-table, #DataTables_Table_0';

  $(tableSelectors).each(function() {
    if ($.fn.DataTable.isDataTable(this)) {
      console.log(`Destroying existing DataTable on: ${this.id || this.className}`);
      $(this).DataTable().destroy();
    }
  });

  console.log("Initializing DataTables...");
  $(tableSelectors).each(function() {
    console.log(`Initializing DataTable for: ${this.id || this.className}`);
    $(this).DataTable({
      "columnDefs": [{
        "targets": 2,
        "orderable": false
      }]
    });
  });

  document.addEventListener("turbolinks:before-cache", function() {
    console.log("Turbolinks:before-cache triggered");
    $(tableSelectors).each(function() {
      if ($.fn.DataTable.isDataTable(this)) {
        console.log(`Destroying DataTable before cache for: ${this.id || this.className}`);
        $(this).DataTable().destroy();
      }
    });
  });
});
