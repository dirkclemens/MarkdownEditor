# Markdown [CheetSheet](https://www.markdownguide.org/cheat-sheet/)

Das ist ein Text in *Italic* und ~~das~~ ist ein Text in **Bold**

das ist ein `code`   
das ist auch ein Code
```
extension View {
    @ViewBuilder
    func cursorOnHover(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
``` 

## Horizontal Rule
---  

# Headings

# H1 
## H2
### H3
#### H4
##### H5
###### H6
####### H7

### Bold  
	**bold text**  
### Italic   
	*italicized text*  
### Blockquote   	
	> blockquote  

## Highlight	
I need to highlight these ==very important words==.

## Ordered List   	
1. First item   
2. Second item   
3. Third item   

## Unordered List  	
- First item  
- Second item  
- Third item  

## Code `code`  

```
{
  "firstName": "John",
  "lastName": "Smith",
  "age": 25
}
```

## Image	

![Screenshot](./images/screenshot.png)   
![Logo](https://adcore.de/ubernaut.png)   
![](./logo.png)  // Works with empty alt text too

## Horizontal Rule
---  

Link	[title](https://www.example.com)  


## Table
| Syntax | Description |
| ----------- | ----------- |
| Header | Title |
| Paragraph | Text |

## Footnote	
Here's a sentence with a footnote. [^1] 

[^1]: This is the footnote.

## Definition List	
term
: definition

## Strikethrough	
~~The world is flat.~~

## Task List	
- [x] Write the press release
- [ ] Update the website
- [ ] Contact the media

## Emoji
(see also Copying and Pasting Emoji)	That is so funny! :joy:

## Highlight
I need to highlight these ==very important words==.

## Subscript
H~2~O

## Superscript
X^2^

