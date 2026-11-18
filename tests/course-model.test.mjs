import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateCourse,normalizeCourse} from '../assets/course-model.js';
const make=()=>({id:'example-course',title:'Example',subtitle:'Example course',category:'Foundations',description:'A sample',outcomes:['Understand the topic'],isSample:true,lessons:[{id:'first-lesson',title:'First lesson',content:'<img src=x onerror=alert(1)>\n\nSecond paragraph',minutes:5,question:'Which?',options:['One','Two','Three'],answer:1,explanation:'Two is correct.'}]});
test('managed lesson content is escaped and never rendered as executable markup',()=>{const c=normalizeCourse(make(),'example-course');assert.ok(c.lessons[0].body.includes('&lt;img'));assert.ok(!c.lessons[0].body.includes('<img'));assert.equal(c.minutes,5);assert.equal(c.isSample,true)});
test('duplicate lesson IDs, unsafe route IDs, and invalid knowledge checks are rejected',()=>{let c=make();c.lessons.push({...c.lessons[0]});assert.throws(()=>validateCourse(c),/unique/);c=make();c.id='../bad';assert.throws(()=>validateCourse(c),/course ID/);c=make();c.lessons[0].answer=4;assert.throws(()=>validateCourse(c),/question/)});

test('public preview remains plain text and reference links must use credential-free HTTPS',()=>{
 const c=make();Object.assign(c,{preview:'A public introduction <script>x</script>',editorialNote:'Newly authored · review pending',sources:[['NHLBI','https://www.nhlbi.nih.gov/health/heart']]});
 const n=normalizeCourse(c,c.id);assert.equal(n.preview,c.preview);assert.deepEqual(n.sources,c.sources);
 for(const url of ['javascript:alert(1)','http://example.com','https://user:password@example.com'])assert.throws(()=>normalizeCourse({...c,sources:[['Unsafe',url]]},c.id),/HTTPS/);
 assert.throws(()=>validateCourse({...c,preview:'x'.repeat(1501)}),/preview/);
});
