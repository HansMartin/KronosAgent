function(task, responses){
    	// If an error happened
    	if(task.status.includes("error")){
        	const combined = responses.reduce( (prev, cur) => {
            		return prev + cur;
        	}, "");
       		return {'plaintext': combined};
    	}	
   
	// should only be one response
	let loginInfo = JSON.parse(responses[0]);

    let out = "";

	out += "Current User: " + loginInfo["domain"] + "\\" + loginInfo["username"] + "\n";
	out += "Currently Impersonating: ";

	if (loginInfo["impersonated"]) {
		out += loginInfo["impUser"];
	} else {
		out+= "-";
	}

    	return {"plaintext": out};
}
