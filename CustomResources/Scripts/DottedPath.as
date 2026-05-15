class DottedLine : ScriptObject
{
    Array<Node@> waypoints;
    Node@ lineNode;

    Array<Vector3> lastPositions;

    float segmentLength = 0.4f;
    float gapLength = 0.3f;

    
    Color lineColor = Color(1.0f, 1.0f, 1.5f.0f, 1.0f);

    float sinusAmplitude = 1.5f;
    int sinusSegments = 20;

    void Start()
    {
        Print("DottedLine: Start() вызван");

        Node@ markersNode = scene.GetChild("markers", true);

        if (markersNode is null)
        {
            Print("Ошибка: узел markers не найден!");
            return;
        }

        waypoints.Resize(6);

        waypoints[0] = markersNode.GetChild("startpos", true);
        waypoints[1] = markersNode.GetChild("point1", true);
        waypoints[2] = markersNode.GetChild("point2", true);
        waypoints[3] = markersNode.GetChild("point3", true);
        waypoints[4] = markersNode.GetChild("point4", true);
        waypoints[5] = markersNode.GetChild("point5", true);

        lastPositions.Resize(waypoints.length);

        for (uint i = 0; i < waypoints.length; i++)
        {
            if (waypoints[i] !is null)
            {
                lastPositions[i] = waypoints[i].worldPosition;
                Print("Точка " + i + ": " + waypoints[i].name);
            }
            else
            {
                Print("Точка " + i + ": НЕ НАЙДЕНА");
            }
        }

        CreateDottedLine();

        SubscribeToEvent("Update", "HandleUpdate");
    }

    void CreateDottedLine()
    {
        
        lineNode = scene.CreateChild("DottedPathLine");

        
        lineNode.position = Vector3(0.0f, 0.05f, 0.0f);

        CustomGeometry@ customGeo =
            lineNode.CreateComponent("CustomGeometry");

        customGeo.SetCastShadows(false);
        customGeo.SetDynamic(true);

        
        customGeo.occludee = false;

        Material@ material = CreateLineMaterial();

        if (material is null)
        {
            Print("Ошибка создания материала");
            return;
        }

        customGeo.SetMaterial(material);

        customGeo.SetNumGeometries(1);

        customGeo.BeginGeometry(0, LINE_LIST);

        
        if (waypoints[0] !is null && waypoints[1] !is null)
        {
            AddStraightLine(
                customGeo,
                waypoints[0].worldPosition,
                waypoints[1].worldPosition
            );
        }

        
        if (waypoints[1] !is null && waypoints[2] !is null)
        {
            AddStraightLine(
                customGeo,
                waypoints[1].worldPosition,
                waypoints[2].worldPosition
            );
        }

        
        if (waypoints[2] !is null && waypoints[3] !is null)
        {
            AddSinusLine(
                customGeo,
                waypoints[2].worldPosition,
                waypoints[3].worldPosition
            );
        }

        
        if (waypoints[3] !is null && waypoints[4] !is null)
        {
            AddStraightLine(
                customGeo,
                waypoints[3].worldPosition,
                waypoints[4].worldPosition
            );
        }

        
        if (waypoints[4] !is null && waypoints[5] !is null)
        {
            AddStraightLine(
                customGeo,
                waypoints[4].worldPosition,
                waypoints[5].worldPosition
            );
        }

        customGeo.Commit();
        customGeo.MarkNetworkUpdate();

        Print("Пунктирная линия создана");
    }

    void AddStraightLine(
        CustomGeometry@ geo,
        Vector3 start,
        Vector3 end
    )
    {
        Vector3 direction = end - start;

        float totalLength = direction.Length();

        if (totalLength < 0.01f)
            return;

        Vector3 dirNormalized = direction.Normalized();

        float t = 0.0f;

        while (t < totalLength)
        {
            Vector3 segStart =
                start + dirNormalized * t;

            float remaining =
                totalLength - t;

            float drawLength =
                segmentLength < remaining ?
                segmentLength :
                remaining;

            Vector3 segEnd =
                segStart +
                dirNormalized * drawLength;

            
            geo.DefineVertex(segStart);
            geo.DefineNormal(Vector3(0.0f, 1.0f, 0.0f));
            geo.DefineTexCoord(Vector2(0.0f, 0.0f));
            geo.DefineColor(lineColor);

            
            geo.DefineVertex(segEnd);
            geo.DefineNormal(Vector3(0.0f, 1.0f, 0.0f));
            geo.DefineTexCoord(Vector2(0.0f, 0.0f));
            geo.DefineColor(lineColor);

            t += segmentLength + gapLength;
        }
    }

    void AddSinusLine(
        CustomGeometry@ geo,
        Vector3 start,
        Vector3 end
    )
    {
        Vector3 direction = end - start;

        float totalLength = direction.Length();

        if (totalLength < 0.01f)
            return;

        Vector3 dirNormalized = direction.Normalized();

        Vector3 right = Vector3(1.0f, 0.0f, 0.0f);

        Vector3 prevPos = start;

        for (int i = 1; i <= sinusSegments; i++)
        {
            float t =
                float(i) / float(sinusSegments);

            Vector3 pointOnLine =
                start +
                dirNormalized * (t * totalLength);

            float offset = 0.0f;

            if (t < 0.33f)
            {
                float t2 = t / 0.33f;

                offset =
                    -sinusAmplitude * t2;
            }
            else if (t < 0.66f)
            {
                float t2 =
                    (t - 0.33f) / 0.33f;

                offset =
                    -sinusAmplitude +
                    2.0f * sinusAmplitude * t2;
            }
            else
            {
                float t2 =
                    (t - 0.66f) / 0.34f;

                offset =
                    sinusAmplitude -
                    sinusAmplitude * t2;
            }

            Vector3 currentPos =
                pointOnLine + right * offset;

            AddStraightLine(
                geo,
                prevPos,
                currentPos
            );

            prevPos = currentPos;
        }
    }

    Material@ CreateLineMaterial()
    {
        Technique@ tech =
            cache.GetResource(
                "Technique",
                "Techniques/NoTextureUnlitVCol.xml"
            );

        if (tech is null)
        {
            Print("Не найдена техника");
            return null;
        }

        Material@ material = Material();

        material.SetTechnique(0, tech);

        material.SetCullMode(CULL_NONE);

        return material;
    }

    void HandleUpdate(
        StringHash eventType,
        VariantMap& eventData
    )
    {
        bool changed = false;

        for (uint i = 0; i < waypoints.length; i++)
        {
            if (waypoints[i] !is null)
            {
                Vector3 currentPos =
                    waypoints[i].worldPosition;

                if (currentPos != lastPositions[i])
                {
                    changed = true;

                    lastPositions[i] = currentPos;
                }
            }
        }

        if (changed)
        {
            RecreateDottedLine();
        }
    }

    void RecreateDottedLine()
    {
        if (lineNode !is null)
        {
            lineNode.Remove();
            @lineNode = null;
        }

        CreateDottedLine();

        Print("Линия обновлена");
    }
}