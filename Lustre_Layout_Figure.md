# Mermaid Diagram of the Lustre Operating Principle

``` mermaid
flowchart TD
%% Nodes
    A("MGS - Management Server")
    D{"Client"}
    E("MDS - MetaData Server")
    F("MST - MetaData Target")
    G("OSS - Object Storage Server")
    H("OST - Object Storage Target")

%% Edge connections between nodes
    D -- Register Client ---> A
    E -- Register MDS & MDT --> A
    G -- Register OSS & OST --> A
    A -- "Inform Client about
    MDS, OSS" --> D
    D <-- 1. Get Metadata ---> E <--> F
    D <-- 2. Get Data ---> G <--> H

%% Individual node styling. Try the visual editor toolbar for easier styling!
    style E color:#FFFFFF, stroke:#AA00FF, fill:#AA00aa
    style G color:#FFFFFF, stroke:#00C853, fill:#00A342
    style D color:#FFFFFF, stroke:#df3A28, fill:#bd1806
    style A color:#FFFFFF, stroke:#0800ff, fill:#0800aa
```
