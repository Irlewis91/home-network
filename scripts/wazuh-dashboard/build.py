#!/usr/bin/env python3
"""Build the "Home network security" dashboard for Wazuh as an NDJSON file.

Import it with the dashboard's saved-objects API (see docs/14-wazuh-dashboard.md):
  python3 build.py > home-network.ndjson

Everything uses Wazuh's standard index patterns (wazuh-alerts-*, and
wazuh-states-vulnerabilities-* for vulnerabilities), so it keeps working when
the Wazuh app creates those patterns itself.
"""
import json

ALERTS = "wazuh-alerts-*"
VULNS = "wazuh-states-vulnerabilities-*"
FAILED_LOGINS = 'rule.groups:("authentication_failed" or "authentication_failures" or "invalid_login")'


def search_source(query="", index=True):
    src = {"query": {"query": query, "language": "kuery"}, "filter": []}
    if index:
        src["indexRefName"] = "kibanaSavedObjectMeta.searchSourceJSON.index"
    return json.dumps(src)


def vis(vid, title, vis_type, aggs, params, query="", index=ALERTS, description=""):
    obj = {
        "type": "visualization",
        "id": vid,
        "attributes": {
            "title": title,
            "description": description,
            "visState": json.dumps({"title": title, "type": vis_type, "aggs": aggs, "params": params}),
            "uiStateJSON": "{}",
            "version": 1,
            "kibanaSavedObjectMeta": {"searchSourceJSON": search_source(query, index is not None)},
        },
        "references": [],
    }
    if index:
        obj["references"].append(
            {"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": index})
    return obj


def count(label):
    return {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {"customLabel": label}}


def terms(agg_id, field, schema, size=10, label=None, order="desc", order_by="1"):
    p = {"field": field, "size": size, "order": order, "orderBy": order_by,
         "otherBucket": False, "missingBucket": False}
    if label:
        p["customLabel"] = label
    return {"id": agg_id, "enabled": True, "type": "terms", "schema": schema, "params": p}


def metric_params(color_ranges=None):
    return {"addTooltip": True, "addLegend": False, "type": "metric", "metric": {
        "percentageMode": False, "useRanges": bool(color_ranges),
        "colorSchema": "Green to Red", "metricColorMode": "Background" if color_ranges else "None",
        "colorsRange": color_ranges or [{"from": 0, "to": 1000000}],
        "labels": {"show": True}, "invertColors": False,
        "style": {"bgFill": "#000", "bgColor": False, "labelColor": False, "subText": "", "fontSize": 36}}}


def xy_params(chart, y_title):
    return {
        "type": chart, "grid": {"categoryLines": False},
        "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "bottom", "show": True,
                          "style": {}, "scale": {"type": "linear"},
                          "labels": {"show": True, "filter": True, "truncate": 100}, "title": {}}],
        "valueAxes": [{"id": "ValueAxis-1", "name": "LeftAxis-1", "type": "value", "position": "left",
                       "show": True, "style": {}, "scale": {"type": "linear", "mode": "normal"},
                       "labels": {"show": True, "rotate": 0, "filter": False, "truncate": 100},
                       "title": {"text": y_title}}],
        "seriesParams": [{"show": True, "type": chart, "mode": "stacked" if chart == "histogram" else "normal",
                          "data": {"label": y_title, "id": "1"}, "valueAxis": "ValueAxis-1",
                          "drawLinesBetweenPoints": True, "lineWidth": 2, "interpolate": "linear",
                          "showCircles": True}],
        "addTooltip": True, "addLegend": True, "legendPosition": "bottom", "times": [],
        "addTimeMarker": False, "labels": {},
        "thresholdLine": {"show": False, "value": 10, "width": 1, "style": "full", "color": "#E7664C"}}


PIE = {"type": "pie", "addTooltip": True, "addLegend": True, "legendPosition": "bottom", "isDonut": True,
       "labels": {"show": False, "values": True, "last_level": True, "truncate": 100}}

TABLE = {"perPage": 10, "showPartialRows": False, "showMetricsAtAllLevels": False,
         "sort": {"columnIndex": None, "direction": None}, "showTotal": False,
         "totalFunc": "sum", "percentageCol": ""}

objects = [
    {"type": "index-pattern", "id": ALERTS,
     "attributes": {"title": ALERTS, "timeFieldName": "timestamp"}, "references": []},
    {"type": "index-pattern", "id": VULNS,
     "attributes": {"title": VULNS}, "references": []},

    vis("hn-header", "How to read this", "markdown", [], {
        "fontSize": 12, "openLinksInNewTab": False,
        "markdown": "**Alert levels:** 0 to 6 routine, 7 to 11 worth a look, 12 and up urgent."}, index=None),

    vis("hn-total", "Alerts", "metric", [count("Alerts")], metric_params()),
    vis("hn-notable", "Worth a look (level 7+)", "metric", [count("Level 7 and up")],
        # Three ranges map to green, amber, red; the red one is out of reach on purpose.
        metric_params([{"from": 0, "to": 1}, {"from": 1, "to": 1000000}, {"from": 1000000, "to": 1000001}]),
        query="rule.level >= 7"),
    vis("hn-urgent", "Urgent (level 12+)", "metric", [count("Level 12 and up")],
        metric_params([{"from": 0, "to": 1}, {"from": 1, "to": 1000000}]), query="rule.level >= 12"),
    vis("hn-failed", "Failed logins", "metric", [count("Failed logins")],
        metric_params([{"from": 0, "to": 1}, {"from": 1, "to": 5}, {"from": 5, "to": 1000000}]),
        query=FAILED_LOGINS),
    vis("hn-devices", "Devices reporting", "metric",
        [{"id": "1", "enabled": True, "type": "cardinality", "schema": "metric",
          "params": {"field": "agent.name", "customLabel": "Devices reporting"}}], metric_params()),

    vis("hn-timeline", "Alerts over time, by device", "line",
        [count("Alerts"),
         {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
          "params": {"field": "timestamp", "useNormalizedOpenSearchInterval": True, "interval": "auto",
                     "drop_partials": False, "min_doc_count": 1, "extended_bounds": {}}},
         terms("3", "agent.name", "group", size=10)],
        xy_params("line", "Alerts")),

    vis("hn-by-device", "Alerts by device", "pie",
        [count("Alerts"), terms("2", "agent.name", "segment", size=10)], PIE),
    vis("hn-by-level", "Alerts by level", "histogram",
        [count("Alerts"), terms("2", "rule.level", "segment", size=16, label="Level",
                                order="asc", order_by="_key")],
        xy_params("histogram", "Alerts")),
    vis("hn-by-group", "What kind of activity", "pie",
        [count("Alerts"), terms("2", "rule.groups", "segment", size=10)], PIE),

    vis("hn-top-rules", "Top alerts", "table",
        [count("Count"), terms("2", "rule.description", "bucket", size=15, label="Alert"),
         terms("3", "rule.level", "bucket", size=1, label="Level")], TABLE),
    vis("hn-notable-list", "Level 7+ alerts", "table",
        [count("Count"), terms("2", "agent.name", "bucket", size=10, label="Device"),
         terms("3", "rule.description", "bucket", size=15, label="Alert")], TABLE,
        query="rule.level >= 7"),
    vis("hn-failed-list", "Failed logins by device and user", "table",
        [count("Attempts"), terms("2", "agent.name", "bucket", size=10, label="Device"),
         terms("3", "data.dstuser", "bucket", size=10, label="User")], TABLE, query=FAILED_LOGINS),
    vis("hn-vulns", "Known vulnerabilities by severity", "table",
        [count("Packages"), terms("2", "vulnerability.severity", "bucket", size=5, label="Severity"),
         terms("3", "agent.name", "bucket", size=10, label="Device")], TABLE, index=VULNS),
]

# Layout on a 48-column grid. On a phone the panels stack in this order.
layout = [
    ("hn-header", 0, 0, 48, 4),
    ("hn-total", 0, 4, 10, 7), ("hn-notable", 10, 4, 10, 7), ("hn-urgent", 20, 4, 10, 7),
    ("hn-failed", 30, 4, 9, 7), ("hn-devices", 39, 4, 9, 7),
    ("hn-timeline", 0, 11, 48, 13),
    ("hn-by-device", 0, 24, 16, 13), ("hn-by-level", 16, 24, 16, 13), ("hn-by-group", 32, 24, 16, 13),
    ("hn-notable-list", 0, 37, 24, 15), ("hn-failed-list", 24, 37, 24, 15),
    ("hn-top-rules", 0, 52, 24, 16), ("hn-vulns", 24, 52, 24, 16),
]
panels, refs = [], []
for n, (vid, x, y, w, h) in enumerate(layout):
    panels.append({"version": "2.19.0", "gridData": {"x": x, "y": y, "w": w, "h": h, "i": str(n + 1)},
                   "panelIndex": str(n + 1), "embeddableConfig": {}, "panelRefName": f"panel_{n}"})
    refs.append({"name": f"panel_{n}", "type": "visualization", "id": vid})

objects.append({
    "type": "dashboard", "id": "home-network-security",
    "attributes": {
        "title": "Home network security",
        "description": "Overview of alerts from every device on the home network",
        "panelsJSON": json.dumps(panels),
        "optionsJSON": json.dumps({"hidePanelTitles": False, "useMargins": True}),
        "version": 1, "timeRestore": True, "timeFrom": "now-24h", "timeTo": "now",
        "refreshInterval": {"pause": False, "value": 300000},
        "kibanaSavedObjectMeta": {"searchSourceJSON": search_source(index=False)},
    },
    "references": refs,
})

for o in objects:
    print(json.dumps(o))
