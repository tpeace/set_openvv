var OVVCallout = function(data) {
  // data object documentation: https://github.com/openvv/openvv#ovvdata

  document.getElementById("progressBar").value = data.percentViewable;

  if(data.percentViewable < 50) {
    document.getElementById("visibilityIcon").className = "unviewable";
  } else {
    document.getElementById("visibilityIcon").className = "viewable";
  }
}
