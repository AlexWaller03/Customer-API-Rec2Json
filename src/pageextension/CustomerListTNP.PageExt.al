pageextension 50100 "Customer List TNP" extends "Customer List"
{
    layout
    {

    }
    actions
    {
        addlast(processing)
        {
            action(ExtractCustTNP)
            {
                ApplicationArea = All;
                Caption = 'Extract Customer';
                ToolTip = 'Extracts the customer to a Json';
                Image = Export;
                trigger OnAction()
                var
                    CustomerAPIManagementTNP: Codeunit "Customer API Management TNP";
                begin
                    CustomerAPIManagementTNP.Run(Rec);
                end;
            }
        }
    }


}
