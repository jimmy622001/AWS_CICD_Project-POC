document.addEventListener('DOMContentLoaded', function() {
    // We would normally fetch this from the backend
    // but for demo purposes, we'll use URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const environment = urlParams.get('env') || 'Unknown';
    const podName = urlParams.get('pod') || 'Unknown';
    const nodeName = urlParams.get('node') || 'Unknown';
    
    document.getElementById('environment').textContent = environment;
    document.getElementById('podName').textContent = podName;
    document.getElementById('nodeName').textContent = nodeName;
});