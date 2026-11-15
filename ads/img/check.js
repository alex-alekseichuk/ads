function checkField(sField,sValue,bRequired,iMin,iMax)
{
	var strError = "";
	var sStrip = sValue;
	sStrip = sStrip.replace(/ /g, "");
	if (sStrip.length == 0 && bRequired)
	{
		strError += "\t" + sField + " field is required\n";
		return strError;
	}
	if (sValue.length > 0)
	{
		if (iMin > 0 && sValue.length < iMin)
			strError += "\t" + sField + " field should have min. " + iMin + " chars\n";
		else if (iMax > 0 && sValue.length > iMax)
			strError += "\t" + sField + " field should have max. " + iMax + " chars\n";
	}
	return strError;
}
function checkSelectField(sField,iIndex)
{
	var strError = "";
	if (iIndex == 0)
		strError += "\t" + sField + " field is required\n";
	return strError;
}
function checkIntField(sField,iValue,iMin,iMax)
{
	if (iValue=="" || isNaN(iValue))
		return "\t" + sField + " field should be Numeric\n";
	if (parseInt(iValue) != iValue)
		return "\t" + sField + " field should be Integer\n";
	if (! isNaN(iMin))
		if (parseInt(iValue) < parseInt(iMin))
			return "\t" + sField + " field should not be less than " + iMin + "\n";
	if (! isNaN(iMax))
		if (parseInt(iValue) > parseInt(iMax))
			return "\t" + sField + " field should not be more than " + iMax + "\n";
	return "";
}
function checkFloatField(sField,iValue,iMin,iMax)
{
	if (iValue=="" || isNaN(iValue))
		return "\t" + sField + " field should be Numeric\n";
	if (! isNaN(iMin))
		if (parseFloat(iValue) < parseFloat(iMin))
			return "\t" + sField + " field should not be less than " + iMin + "\n";
	if (! isNaN(iMax))
		if (parseFloat(iValue) > parseFloat(iMax))
			return "\t" + sField + " field should not be more than " + iMax + "\n";
	return "";
}

function checkCheckField(sField,objForm,iCount)
{
	var strError = "";
	var i;
	var bCheck;
	if (iCount=='1') {
		if (objForm.checked)  bCheck = true;
	}
	else{
		for(i=0; i<iCount; i++){
			if (objForm[i].checked)  bCheck = true;
		}
	}
	if (!bCheck) strError=strError += "\t" + sField + " field is required\n";
	return strError;
}
