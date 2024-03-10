codeunit 50100 "Customer API Management TNP"
{
    TableNo = Customer;

    trigger OnRun()
    var
        responseText: Text;
    begin
        SendPayload(RectoJson(Rec), 'https://webhook.site/cc2b13ad-985f-4ebb-9b73-acdeeb691f5b', '', 'post', responseText);
    end;

    local procedure RectoJson(var Customer: Record Customer): JsonObject
    var
        Fields: Record Field;
        RecRef: RecordRef;
        FieldRef: FieldRef;
        JsonObject: JsonObject;
        TB: TextBuilder;
        i: Integer;
    begin
        RecRef.GetTable(Customer);

        // Fields.SetRange(Tableno, Database::Customer);
        // Fields.SetFilter("No.", '<%1', Customer.FieldNo(SystemId));
        // if Fields.FIndSet() then
        //     repeat
        //         if TB.Length = 0 then
        //             TB.Append(Format(Fields."No."))
        //         else
        //             TB.Append(',' + Format(Fields."No."))
        //     until Fields.Next() = 0;

        // Message(TB.ToText());

        for i := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(i);
            case FieldRef.Class() of
                FieldClass::Normal:
                    JsonObject.Add(GetJsonFieldName(FieldRef), FieldReftoJsonValue(FieldRef));
                FieldClass::FlowField:
                    begin
                        FieldRef.CalcField();
                        JsonObject.Add(GetJsonFieldName(FieldRef), FieldReftoJsonValue(FieldRef));
                    end;
            end;
        end;


        exit(JsonObject);
    end;

    local procedure FieldReftoJsonValue(FieldRef: FieldRef): JsonValue
    var
        JsonValue: JsonValue;
        Date: Date;
        Time: Time;
        DateTime: DateTime;
    begin
        case FieldRef.Type of
            FieldType::Date:
                begin
                    Date := FieldRef.Value();
                    JsonValue.SetValue(Date);
                end;
            FieldType::Time:
                begin
                    Time := FieldRef.Value();
                    JsonValue.SetValue(Time);
                end;
            FieldType::DateTime:
                begin
                    DateTime := FieldRef.Value();
                    JsonValue.SetValue(DateTime);
                end;
            else
                JsonValue.SetValue(Format(FieldRef.Value(), 0, 9));
        end;
        exit(JsonValue);
    end;

    local procedure GetJsonFieldName(FieldRef: FieldRef): Text
    var
        FieldName: Text;
        i: Integer;
    begin
        FieldName := FieldRef.Name();
#pragma warning disable AA0005   //Necessary to exit the fieldname out of the for loop
        for i := 1 to StrLen(FieldName) do begin
            if FieldName[i] < '0' then
                FieldName[i] := '_';
        end;
#pragma warning restore AA0005
        exit(FieldName.Replace('__', '_').TrimEnd('_').TrimStart('_'));
    end;

    local procedure SendPayload(JsonContent: JsonObject; BaseUrl: Text; Service: Text; Method: Text; var ResponseText: Text) ReturnValue: Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Request: HttpRequestMessage;
        WriteStream: OutStream;
        ContentText: Text;
    begin
        CreateRequest(Request, Method, CombineUrl(BaseUrl, Service));

        // add content
        if JsonContent.Values().Count() > 0 then begin
            JsonContent.WriteTo(ContentText);
            CreateContent(Request, ContentText);
        end;

        ResponseText := SendRequest(Request, '');
        if StrLen(ResponseText) = 0 then
            exit;

        TempBlob.CreateOutStream(WriteStream);
        WriteStream.WriteText(ResponseText);
        ReturnValue := true;
    end;


    local procedure SendRequest(Request: HttpRequestMessage; Token: Text) ReturnValue: Text;
    var
        WebClient: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        CacheControlLbl: Label 'Cache-Control';
        CacheControlTxt: Label 'no-cache';
        OcpApimSubscriptkeyLbl: Label 'Ocp-Apim-Subscription-Key';
        ErrorMessageLbl: Label 'Request Status: %1', Comment = '%1 is Response Text';
    begin
        if StrLen(Token) > 0 then begin
            WebClient.DefaultRequestHeaders.Add(CacheControlLbl, CacheControlTxt);
            WebClient.DefaultRequestHeaders().Add(OcpApimSubscriptkeyLbl, Token);
        end;

        if WebClient.Send(Request, Response) then
            Response.Content().ReadAs(ResponseText);

        if Response.IsSuccessStatusCode() then
            Response.Content().ReadAs(ReturnValue)
        else
            if Response.HttpStatusCode <> 404 then // 404 return blank, record not found
                Error(ErrorMessageLbl, ResponseText);
    end;


    local procedure CreateRequest(var Request: HttpRequestMessage; Method: Text; Url: Text)
    begin
        Request.SetRequestUri(Url);
        Request.Method := Method;
    end;

    local procedure CreateContent(var Request: HttpRequestMessage; RequestText: Text)
    var
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        ContentTypeLbl: Label 'Content-Type';
        ContentTypeValueLbl: Label 'application/json';
    begin
        Content.WriteFrom(RequestText);

        Content.GetHeaders(ContentHeaders);

        ContentHeaders.Clear();
        ContentHeaders.Add(ContentTypeLbl, ContentTypeValueLbl);
        Request.Content := Content;
    end;


    local procedure CombineUrl(BaseUrl: Text; Service: Text) ReturnValue: Text;
    var
        UrlFormatTxt: Label '%1%2', Comment = '%1 is Base Url, %2 is Service';
        FwdSlashTxt: Label '/';
    begin
        if StrLen(Service) = 0 then
            exit(BaseUrl);

        case true of
            Format(BaseUrl).EndsWith(FwdSlashTxt):
                if Service.StartsWith(FwdSlashTxt) then
                    ReturnValue := StrSubstNo(UrlFormatTxt, BaseUrl, CopyStr(Service, 2, StrLen(Service)))
                else
                    ReturnValue := StrSubStno(UrlFormatTxt, BaseUrl, Service);
            Format(Service).StartsWith(FwdSlashTxt):
                ReturnValue := StrSubStno(UrlFormatTxt, BaseUrl, Service);
            else
                ReturnValue := StrSubStno(UrlFormatTxt, StrSubStno(UrlFormatTxt, BaseUrl, FwdSlashTxt), Service);
        end;
    end;

}
