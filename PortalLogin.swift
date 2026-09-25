import Foundation
import WebKit

/// Port of Android's PortalLogin: captcha detection + credential autofill.
/// CRITICAL: the portal spells the code field "Capcha" (MainContent_Capcha) —
/// the regex must match capcha, not just captcha.
enum PortalLogin {
    static let loginURL = URL(string: "https://studentservice.iust.ac.in/Account/login")!
    static let homeURL = URL(string: "https://www.iust.ac.in/")!

    static let captchaDetectJS = """
    function __iustHasCaptcha(){
      var imgs=document.querySelectorAll('img');
      for(var i=0;i<imgs.length;i++){
        var s=((imgs[i].src||'')+' '+(imgs[i].id||'')+' '+(imgs[i].alt||'')).toLowerCase();
        if(s.indexOf('captcha')!==-1||s.indexOf('capcha')!==-1)return true;
      }
      var ins=document.querySelectorAll('input');
      for(var j=0;j<ins.length;j++){var el=ins[j];
        var t=(el.type||'text').toLowerCase();
        if(t!=='text'&&t!=='')continue;
        var n=((el.name||'')+' '+(el.id||'')).toLowerCase();
        if(/captcha|capcha|verif/.test(n))return true;
      }
      return false;
    }
    """

    static let loginStateJS = """
    (function(){
    \(captchaDetectJS)
    var hasPass=false;
    var inputs=document.querySelectorAll('input');
    for(var i=0;i<inputs.length;i++){
      if(((inputs[i].type)||'').toLowerCase()==='password'){hasPass=true;break;}
    }
    var hasCourse=false;
    var direct=document.getElementById('cphMain_dlCourses');
    if(direct){hasCourse=true;}
    else{var sels=document.querySelectorAll('select');
      for(var j=0;j<sels.length;j++){
        if(sels[j].querySelectorAll('option').length>2){hasCourse=true;break;}
      }
    }
    return JSON.stringify({login:hasPass,attendance:hasCourse,captcha:__iustHasCaptcha()});
    })();
    """

    private static func jsEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Fills username + password, ticks "Remember me?", focuses the captcha
    /// code field and returns WITHOUT submitting when a captcha is present.
    /// The user types the code + taps Log in themselves — never auto-solved.
    static func autofillJS(username: String, password: String) -> String {
        """
        (function(){
        \(captchaDetectJS)
        function setVal(el,v){
          try{var d=Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el),'value');
          if(d&&d.set){d.set.call(el,v);}else{el.value=v;}}catch(e){el.value=v;}
          el.dispatchEvent(new Event('input',{bubbles:true}));
          el.dispatchEvent(new Event('change',{bubbles:true}));}
        var inputs=document.querySelectorAll('input'),u=null,p=null,firstText=null;
        for(var i=0;i<inputs.length;i++){var el=inputs[i];
          var t=(el.type||'text').toLowerCase();
          if(el.disabled||el.readOnly||t==='hidden'||t==='submit'||t==='button'
            ||t==='checkbox'||t==='radio'||t==='file')continue;
          if(t==='password'){if(!p)p=el;continue;}
          var s=((el.name||'')+' '+(el.id||'')+' '+(el.placeholder||'')+' '
            +(el.getAttribute('autocomplete')||'')).toLowerCase();
          if(!u&&/user|login|reg|roll|enroll|student|email/.test(s)){u=el;continue;}
          if(!firstText&&(t==='text'||t==='email'||t===''))firstText=el;}
        if(!u)u=firstText;
        if(u)setVal(u,'\(jsEscape(username))');
        if(p)setVal(p,'\(jsEscape(password))');
        var capInput=null,all2=document.querySelectorAll('input');
        for(var k=0;k<all2.length;k++){var e2=all2[k];
          if(e2===u||e2===p)continue;
          var t2=(e2.type||'text').toLowerCase();
          if(t2==='checkbox'){
            var rs=((e2.name||'')+' '+(e2.id||'')).toLowerCase();
            var lbl='';try{lbl=e2.parentNode?e2.parentNode.innerText:'';}catch(x){}
            if(/remember/.test(rs+' '+String(lbl).toLowerCase())&&!e2.checked){e2.click();}
            continue;}
          if(t2==='text'||t2===''){
            var cs=((e2.name||'')+' '+(e2.id||'')+' '+(e2.placeholder||'')).toLowerCase();
            if(/captcha|capcha|verif|code/.test(cs)&&!capInput){capInput=e2;}}}
        if(!capInput&&__iustHasCaptcha()){
          for(var m=0;m<all2.length;m++){var e3=all2[m];var t3=(e3.type||'text').toLowerCase();
            if(e3!==u&&e3!==p&&t3!=='password'&&t3!=='checkbox'&&t3!=='hidden'
              &&t3!=='submit'&&t3!=='button'){capInput=e3;break;}}}
        if(capInput){try{capInput.focus();capInput.scrollIntoView();}catch(e){}
          return 'captcha';}
        var done=(u&&p)?'filled':((u||p)?'partial':'notfound');
        if(done==='filled'){var f=u.form||p.form;
          if(f&&f.requestSubmit){try{f.requestSubmit();done='submitted';}catch(e){}}
          if(done==='filled'){var b=document.querySelector('button[type=submit],input[type=submit]');
            if(b){b.click();done='submitted';}}}
        return done;})();
        """
    }

    /// Attendance table scraper — returns JSON [{n:name, p:pct}]
    static let attendanceScrapeJS = """
    (function(){
      function txt(s){return (s||'').replace(/\\s+/g,' ').trim();}
      var out=[];
      var tables=document.querySelectorAll('table');
      for(var t=0;t<tables.length;t++){
        var headers=[];
        tables[t].querySelectorAll('th').forEach(function(h){headers.push(txt(h.innerText).toLowerCase());});
        var hstr=headers.join(' ');
        if(hstr.indexOf('attend')===-1&&hstr.indexOf('%')===-1&&hstr.indexOf('percent')===-1)continue;
        var nameIdx=-1,pctIdx=-1;
        for(var i=0;i<headers.length;i++){
          if(nameIdx===-1&&/subject|course|paper|name|title/.test(headers[i]))nameIdx=i;
          if(pctIdx===-1&&/percent|%|attend/.test(headers[i]))pctIdx=i;
        }
        if(pctIdx===-1)pctIdx=headers.length-1;
        if(nameIdx===-1)nameIdx=0;
        tables[t].querySelectorAll('tbody tr').forEach(function(tr){
          var cells=tr.querySelectorAll('td');
          if(cells.length<=Math.max(nameIdx,pctIdx))return;
          var name=txt(cells[nameIdx].innerText);
          var pctTxt=txt(cells[pctIdx].innerText);
          var m=pctTxt.match(/([0-9]+(?:\\.[0-9]+)?)/);
          if(name&&m){out.push({n:name.slice(0,80),p:parseFloat(m[1])});}
        });
        if(out.length>0)break;
      }
      return JSON.stringify(out);
    })();
    """
}
