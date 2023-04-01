#!/usr/bin/env python
"""
The purpose of this script is to 
    1. Take as input a cell block
    2. Find and parse the output html file (or create it if it doesn't exists)
    3. Write/substitute the new content of the block to the old one
    4. Wait for the output of the block
    5. Write/subsitute the output of the block
"""

import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from bs4 import BeautifulSoup
from time import sleep
import logging
from collections import OrderedDict


class Listener:
    vimfile = Path("/tmp/blockcontent.txt").absolute()
    outfile = Path("/tmp/outputcontent.txt").absolute()
    env = Environment(loader=FileSystemLoader('templates'))
    template_html = env.get_template('block_content.html')

    def __init__(self, filepath):
        self.filepath = Path(filepath).expanduser().absolute()
        self.htmlpath = self.filepath.with_suffix('.html')
        self.html_tags = self.parse_tags()

    def read_html(self):
        if not self.htmlpath.is_file():
            return ""
        elif self.htmlpath.stat().st_size == 0:
            return ""
        else:
            with self.htmlpath.open("r") as f:
                return f.read()

    def parse_tags(self):
        bs = BeautifulSoup(self.read_html(), features="html.parser")
        html_tags = OrderedDict({int(x['id']): str(x.parent) for x in bs.find_all("h2")})
        return html_tags


    def read_vim_file(self):
        with self.vimfile.open("r") as f:
            return f.read()

    def parse_block(self, block_content):
        lines = block_content.split('\n')
        header = lines[0]
        block_id = int(re.findall("[0-9]+", header)[0])
        block_body = "<br/>".join(lines[1:-1])
        return block_id, block_body

    def parse_output(self, output_content):
        plot_path = output_content.split('\n')[0] # TODO add option in case there is no plot
        return plot_path

    def update_html_content(self, block_parsed, output_parsed):
        block_id, block_body = block_parsed
        plot_path = output_parsed
        html = self.template_html.render(
                block_id = block_id,
                block_body = block_body,
                plot_path = plot_path,
                )
        self.html_tags[block_id] = html

    def write_html(self):
        with self.htmlpath.open("w") as f:
            keys = list(self.html_tags.keys())
            keys.sort()
            new_html = "\n".join([self.html_tags[i] for i in keys])
            f.write(new_html)

    def read_output_file(self):
        if not self.outfile.is_file():
            sleep(0.3) # TODO add timeout
            return self.read_output_file()
        with self.outfile.open("r") as f:
            return f.read()

    def run(self):
        block_content = self.read_vim_file()
        output_content = self.read_output_file()
        block_parsed= self.parse_block(block_content)
        output_parsed = self.parse_output(output_content)
        self.update_html_content(block_parsed, output_parsed)
        self.write_html()
        self.vimfile.unlink()
        # self.outfile.unlink()

if __name__ == "__main__":
    import sys
    L = Listener(sys.argv[1])
    L.run()

if 1 == 0: #debug
    L = Listener("prova.jl")
    block_content = L.read_vim_file()
    output_content = L.read_output_file()
    block_parsed= L.parse_block(block_content)
    output_parsed = L.parse_output(output_content)
    L.update_html_content(block_parsed, output_parsed)
    L.html_tags
    
