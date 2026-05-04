async function deploy(){
let win10=document.getElementById("win10").value||0;
let linux=document.getElementById("linux").value||0;

await fetch("/deploy",{
method:"POST",
headers:{"Content-Type":"application/json"},
body:JSON.stringify({win10:parseInt(win10),linux:parseInt(linux)})
});

alert("Deployment started");
}

async function destroyInfra(){
await fetch("/destroy",{method:"POST"});
alert("Destroyed");
}

async function load(){
let res=await fetch("/status");
let data=await res.json();

let table=document.getElementById("table");
table.innerHTML="<tr><th>Name</th><th>IP</th><th>Status</th></tr>";

let w10=0,lin=0;

for(let k in data){
let arr=data[k].value||[];
arr.forEach(ip=>{
if(k.includes("win10"))w10++;
if(k.includes("linux"))lin++;

table.innerHTML+=`<tr><td>${k}</td><td>${ip}</td><td class='online'>ONLINE</td></tr>`;
});
}

document.getElementById("win10_count").innerText=w10;
document.getElementById("linux_count").innerText=lin;
}

setInterval(load,5000);
load();
