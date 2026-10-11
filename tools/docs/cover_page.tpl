{#- Cover page of the printed manual (mkdocs-print-site-plugin).
    Variables: config (mkdocs.yml). Styled by docs/assets/stylesheets/print.css. -#}
<div class="smx-cover">
  <p class="smx-cover-kicker">SmartManipulator-X robot arm</p>
  <h1 class="smx-cover-title">{{ config.site_name }}</h1>
  <p class="smx-cover-subtitle">Robot PC, controller firmware, hardware and system architecture</p>
  <p class="smx-cover-lead">{{ config.site_description }}</p>

  <table class="smx-cover-meta">
    <tr><th>Document version</th><td>{{ config.extra.doc_version }}</td></tr>
    {%- if config.extra.doc_date %}
    <tr><th>Date</th><td>{{ config.extra.doc_date }}</td></tr>
    {%- endif %}
    <tr><th>Robot PC</th><td>Ubuntu 24.04, ROS 2 Jazzy in Docker</td></tr>
    <tr><th>Controller</th><td>Microchip SmartFusion2 M2S Hello FPGA Kit (M2S010), Zephyr RTOS</td></tr>
    <tr><th>Protocol</th><td>DYNAMIXEL Protocol 2.0, 230400 bps</td></tr>
    {%- if config.site_author %}
    <tr><th>Author</th><td>{{ config.site_author }}</td></tr>
    {%- endif %}
    {%- if config.repo_url %}
    <tr><th>Repository</th><td>{{ config.repo_url }}</td></tr>
    {%- endif %}
  </table>
</div>
